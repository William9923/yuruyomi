# yuruyomi

**yuruyomi** is a fork based on **rakuyomi** , a manga reader plugin for [KOReader](https://github.com/koreader/koreader). Just for a learning & hobby projects on free time using **rakuyomi**, one of my favourite koreader plugins.


## Reference
- [rakuyomi](https://github.com/hanatsumi/rakuyomi)


## Plan

How does the UI experience I would like ?

Library:
1. List of manga in libraries:
- current: ListView
- proposed:
  Mosaic list view (might be the best tho...):
  - Manga cover:
  - with metadata details:
    - Manga Name (in bold)
    - Source
    - Total chapter
  (Plugin reference: coverbrowser)

2. Search: => how does mihon had different search??
- current: search only by text
- proposed:
  - sort by popularity or any other kind of  (dropdown options)

- long term proposed (v2):
  - customized search per source (like mihon)

3. Detailed view of a manga -> after search result
- current: Immediate Chapter Listing
- proposed:
 - mihon showcase, where we show:
 1. cover
 2. title
 3. description
 4. manga tag (if there any)
 5. writer
4. Download experience
- current:
  1. Only allow download unread
- proposed:
  1. Allow download:
     - Next 5 unread
     - Next 10 unread
     - Next 20 unread
     - Custom (use the same approach)
  2. Chapter number / index number (by index number) -> custom input

5. Download location
- current:
  All into same folder -> yuruyomi download folder
- proposed:
  Each source - manga -> have their own separate folder
  (basically, we can create a hash to build it the hash key as folder)

Todo this:
1. Backend ??
2. Frontend where does the file fetch information comes from...
