# yuruyomi

**yuruyomi** is a fork based on **rakuyomi** , a manga reader plugin for [KOReader](https://github.com/koreader/koreader). Just for a learning & hobby projects on free time using **rakuyomi**, one of my favourite koreader plugins.


## Reference
- [rakuyomi](https://github.com/hanatsumi/rakuyomi)


## Plan

How does the UI experience I would like ?

1. Download experience
- current:
  1. Only allow download unread
- proposed: -> DONE
  1. Allow download: -> DONE
     - Next 5 unread
     - Next 10 unread
     - Next 20 unread
     - Custom (use the same approach)

  2. Refresh chapters list -> DONE
  3. Delete reading history -> DONE
  6. Dismissable immediate read -> DONE
  4. Delete download -> IN PROGRESS
    Flow:
    1. Backend Implementation
     - I think it make sense to have both delete all in manga, and delete per chapter
     - Once we had abilities to download per chapter, we should also expose capabilities to delete per chapter i believe
     - Backend done
    2. Frontend Implementation Flow
     - Implement 2 types
     - Per chapter deletion (api exposed)
     - All chapter in manga (you can traverse and apply 1 by 1, interruptable bcs it might take time) -> if possible show progress, should be easy ? Good progress bar training
  --- next release -> 0.1
  5. Custom per source folder
  7. Proper progress bar dialog -> download single & download many
  --- next release -> 0.2
  3. Download on demand (like mihon), via button -> IN PROGRESS
  4. Show Download Queue Manager per chapter, max showing 5 (or via settings) (linear 1 at a time on background), dialog


2. List of manga in libraries + manga finder:
- current: ListView
- proposed:
  Mosaic list view (might be the best tho...):
  - Manga cover:
  - with metadata details:
    - Manga Name (in bold)
    - Source
    - Total chapter
  (Plugin reference: coverbrowser)


3. Detailed view of a manga -> after search result
- current: Immediate Chapter Listing
- proposed:
 - mihon showcase, where we show:
 1. cover
 2. title
 3. description
 4. manga tag (if there any)
 5. writer
 6. Show chapter list


4. Search & Manga Discovery: => how does mihon had different search??
- current: search only by text
- proposed:
  - sort by popularity or any other kind of  (dropdown options)

- long term proposed (v2):
  - customized search per source (like mihon)
