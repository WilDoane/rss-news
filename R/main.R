############################################################################
# Written By: William E. J. Doane <wil@DrDoane.com>
# Created On: December 15, 2021
# RSS harvester and newsletter generator
############################################################################

# Overload default behavior to install missing packages --------------------

`%!in%` <- function(x, table) {
  !(x %in% table)
}

library <- function(pkg, ...) {
  pkg <- sapply(substitute(list(pkg))[[-1]], deparse)
  
  install.packages(pkg[!pkg %in% installed.packages()[,1]], dependencies = TRUE)
  invisible(base::library(pkg, character.only = TRUE, ...))
}

suppressPackageStartupMessages({
  library(here)
  library(janitor)
  
  library(httr)
  library(readr)
  
  library(purrr)
  library(dplyr)
  library(stringr)
  library(textutils)
  
  library(tidyRSS)
  
  library(officer)
  
  # library(mailR)
})

config_path <- here::here("data")
rss_path <- here::here("downloaded-rss-items")
output_path <- here::here("output")
errors_path <- here::here(config_path, "errors.txt")

dir.create(rss_path, showWarnings = FALSE)
dir.create(output_path, showWarnings = FALSE)

last_ran_filename <- here::here(config_path, "last_ran.txt")

last_ran <- 
  if (file.exists(last_ran_filename)) {
    as.Date(readLines(last_ran_filename))
  } else {
    Sys.Date() - 1
  }

window <- 1 # keep this number of days of stories

# Harvest RSS feeds -------------------------------------------------------

message("Harvesting RSS feeds...")

urls <- read_csv(
  here::here(config_path, "news-feeds.csv"), 
  show_col_types = FALSE, 
  comment = "#",
  skip_empty_rows = TRUE
)

down_select <- function(data) {
  data %>% 
    select(any_of(c("feed_title", "item_title", "item_link", "item_description", "item_pub_date")))
}

unlink(errors_path)

rss_items_lst <- 
  pmap(urls, function(url) {
    filename <- file.path(rss_path, Sys.Date(), paste0(make_clean_names(url), ".csv"))
    message("  ", url)
    
    dir.create(dirname(filename), showWarnings = FALSE, recursive = TRUE)
    
    if (!file.exists(filename)) {
      tryCatch({
        # download new feeds
        tidyfeed(url, parse_dates = TRUE) %>% 
          write_csv(filename) %>% 
          down_select()
      }, error = function(e) {
        write(url, file = errors_path, append = TRUE)
      }
      )
    } else {
      # load already downloaded feeds
      read_csv(filename, show_col_types = FALSE) %>% 
        down_select()
    }
  }) 

if (file.exists(errors_path)) {
  # Remove URLs for feeds that errored
  bad_urls <- readLines(errors_path)
  
  good_urls <- urls[urls$url %!in% bad_urls, ]
  
  write_csv(good_urls, here::here(config_path, "news-feeds.csv"))
}

# Extract new RSS items
rss_items <- 
  map_df(
    rss_items_lst, 
    
    function(rss_items) {
      if ("tbl_df" %in% class(rss_items)) {
        rss_items 
      }
    }) %>% 
  # Only keep recently published items
  filter(last_ran - window <= item_pub_date) %>% # published within last few days
  filter(!is.na(item_pub_date)) %>% 
  
  # Only one copy of a story across feeds  
  distinct(item_title, .keep_all = TRUE) %>% 
  
  write_csv(file.path(rss_path, paste0(Sys.Date(), "_all_rss_items.csv")))

rm(rss_items_lst)

# Generate Microsoft Word Reports -----------------------------------------

message("Generating reports...")

generate_docx <- function(docx, term, items, trunc = 300) {
  # Using officer to construct an MS Word document

  body_add_par(docx, term, style = "heading 1")
  body_add_par(docx, "")
  
  for (i in 1:nrow(items)) {
    message("\014", term, " item ", i, " of ", nrow(items))
    
    try({
      fp <- fpar(hyperlink_ftext(
        text = items %>% slice(i) %>% pull("item_title") %>% HTMLdecode() %>% trimws(), 
        href = items %>% slice(i) %>% pull("item_link"))
      )
      
      body_add_fpar(docx, fp, style = "heading 2")
      
      # body_add_par(
      #   docx, 
      #   paste0("Source: ", items %>% slice(i) %>% pull("feed_title")),
      #   style = "Balloon Text"
      # )
      article <- paste0(
        substr(as.character(items[i, "item_description"]), 1, trunc), "..."
      )

      for (p in unlist(str_split(article, "(<br>|<br/>|\n|\r\n)+"))) {
        body_add_par(docx, HTMLdecode(paste0(p, " ")))
      }
      
      # body_add_break(docx)
    }, silent = TRUE)
  }
}


## Generate omnibus report -------------------------------------------------

optional_create_omnibus <- function() {
  # This will likely take far too long to execute to be useful
  docx <- 
    read_docx() %>% 
    body_add_toc(level = 1) %>% 
    body_add_break() %>% 
    body_add_toc(level = 2) %>% 
    body_add_break()
  
  generate_docx(docx, "All Stories", rss_items)
  
  print(docx, file.path(output_path, paste0(Sys.Date(), "_", "all_stories.docx")))
}



## Generate per-topic reports ----------------------------------------------

watch_terms <- read_csv(
  here::here(config_path, "watch-terms.csv"), 
  show_col_types = FALSE,
  comment = "#",
  skip_empty_rows = TRUE
)

walk(split(watch_terms, ~topic), function(df) {
  topic <- df %>% slice(1) %>% pull(topic)
  topic_filename <- file.path(output_path, paste0(Sys.Date(), "_", topic, ".docx"))
  
  message("  ", topic)
  
  if (!file.exists(topic_filename)) {
    docx <- read_docx() %>% 
      body_add_toc(level = 1) %>% 
      body_add_break() %>% 
      body_add_toc(level = 2) %>% 
      body_add_break()
    
    pwalk(df, function(topic, term, pattern) {
      message(term)
      
      items <-  
        rss_items[1:100,] %>% 
        filter(
          str_detect(item_title, regex(pattern, ignore_case = TRUE)) | 
            str_detect(item_description, regex(pattern, ignore_case = TRUE))
        ) 
      
      if (nrow(items) > 0) generate_docx(docx, term, items)
    })
    
    print(docx, topic_filename)
    
    message("    ... compiled")
  } else {
    message("    ... previously compiled")
  }
})



optional_email_subscribers <- function() {
  # Send Email to Subscribers -----------------------------------------------
  subscribers_filename <- here::here("data", "subscribers.csv")
  
  if (!file.exists(subscribers_filename)) { return(invisible(NULL)) }
    
  debug_only <- TRUE
  
  # Must be updated to match your organization's settings
  # May need to obtain permission from IT department to use outgoing SMTP mail server
  smtp_server <- "replace-with-organizations-smtp-server.com"
  from <- "YourUsername@YourServer.com"
  
  subject <- "News Items"
  body <- "Attached are the news feeds to which you subscribe."
  
  
    subscribers <- read_csv(
      subscribers_filename, 
      show_col_types = FALSE,
      comment = "#",
      skip_empty_rows = TRUE
    )
    
    pwalk(subscribers, function(email, topics) {
      
      attachments <-
        topics %>% 
        str_split(";") %>% 
        unlist() 
      
      attachments <-
        file.path(here::here("output"), paste0(Sys.Date(), "_", attachments, ".docx"))
      
      attachments <- attachments[file.exists(attachments)]
      
      if (length(attachments) > 0) {
        # Documentation available at https://github.com/rpremrajGit/mailR
        send.mail(
          from = from,
          to = email,
          subject = subject,
          body = body,
          smtp = list(host.name = smtp_server),
          send = !debug_only,
          attach.files = attachments
        )
      }
    })
}

writeLines(as.character(Sys.Date()), last_ran_filename)

message("Review the generated content in output/")
  