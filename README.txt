This RStudio project is designed to take a list of RSS feed URLS, download news 
items from them, then produce a number of Microsoft Word documents reporting
the RSS items that match a given set of key terms.

RSS FEED URLS
==========================================================================

The feed URLs are stored in data-raw/news-feeds.csv

That file contains a header row followed by URLS pointing to RSS feeds,
  one URL per row. Blank lines and lines beginning with # are ignored.
  
For information on the purpose and design of RSS: 
  https://en.wikipedia.org/wiki/RSS

RSS feed URLs can often be found by searching for them directly. E.g.,

  nytimes science rss feed
  
returns a page at https://rss.nytimes.com/ where various feed URLs can be found.

Similarly for:

  state department rss feed
  nasa rss feed
  
and so on.
  
  
KEY TERMS
==========================================================================
The key terms to search for are stored in data-raw/watch-terms.csv

That file contains a header row followed by one regular expression per row.
  Blank lines and lines beginning with # are ignored.

Regular expressions are patterns to be searched for in text. 

  science
  
is a regular expression as is

  scien[^ ]+

The first "matches" when it finds at least the exact sequence of characters
  s c i e n c e in the title or description of a downloaded RSS item.
  
The second "matches" when it finds at least the exace sequence
  s c i e n 
followed by one or more non-space characters, denoted here by [^ ]+ .

For information on the purpose and design of regular expressions: 
  https://en.wikipedia.org/wiki/Regular_expression
  https://drdoane.com/regular-expression-builder/
  
watch-terms.csv contains 3 columns:

  * topic:   A broad grouping label for one or more terms (e.g., Biology)
  * term:    A human-readable name for the pattern (e.g., digestion, aging)
  * pattern: A regular expression to search for (e.g., digest[^ ]+)
  
A report document will be created for each topic with one section per term
  for which there were matched RSS items in that topic.
  
Reports are generated in the output/ folder.

RSS items may appear in more than one report, if multiple patterns are matched.
  For example, is there exists watch-terms
  
  computing,Microelectronics,(microcircuit|microelectronic|chip)s?
  computing,Computing,computers?

  then an RSS item with a title such as "Computer chips" would appaer in the
  computing.docx report in both the Computing section and the 
  Microelectronics section.
  
  
SENDING EMAIL TO SUBSCRIBERS
==========================================================================
The list of active subscribers are stored in data-raw/subscribers.csv

The file contains a header row followed by one subscriber per row.
  Blank lines and lines beginning with # are ignored.

The email address and a semi-colon list of topics subscribed to are given.

The topics must match exactly a topic in the data-raw/watch-terms.csv
  file in order for the generated DOCX report to be identified and emailed.

An example subscribers.csv file:

email,topics  
person1@organization.com,adastra;computing;biology
person2@organization.com,computing




