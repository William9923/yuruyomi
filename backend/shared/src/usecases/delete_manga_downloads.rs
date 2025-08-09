use anyhow::Result;
use log::debug;

use crate::{
    chapter_storage::ChapterStorage,
    database::Database,
    model::{ChapterId, MangaId},
};

pub async fn delete_manga_downloads(
    database: &Database,
    chapter_storage: &ChapterStorage,
    manga_id: MangaId,
) -> Result<usize> {
    debug!("Deleting all downloads for manga: {:?}", manga_id);
    
    // First, get all cached chapters for this manga from the database
    let chapters = database.find_cached_chapter_informations(&manga_id).await;
    
    let mut deleted_count = 0;
    
    // Delete each chapter that is downloaded
    for chapter in chapters {
        let chapter_id = chapter.id; // chapter.id is already a ChapterId
        
        // Check if this chapter is actually downloaded
        if chapter_storage.get_stored_chapter(&chapter_id).is_some() {
            match chapter_storage.delete_chapter(&chapter_id).await {
                Ok(_) => {
                    deleted_count += 1;
                    debug!("Successfully deleted chapter: {}", chapter_id.value());
                }
                Err(e) => {
                    debug!("Failed to delete chapter {}: {}", chapter_id.value(), e);
                    // Continue with other chapters even if one fails
                }
            }
        }
    }
    
    debug!("Deleted {} chapters for manga: {:?}", deleted_count, manga_id);
    Ok(deleted_count)
}

pub async fn delete_chapter_download(
    chapter_storage: &ChapterStorage,
    chapter_id: ChapterId,
) -> Result<bool> {
    debug!("Deleting download for chapter: {:?}", chapter_id);
    
    // Check if the chapter is actually downloaded
    if chapter_storage.get_stored_chapter(&chapter_id).is_none() {
        debug!("Chapter {} is not downloaded", chapter_id.value());
        return Ok(false);
    }
    
    chapter_storage.delete_chapter(&chapter_id).await?;
    debug!("Successfully deleted chapter: {}", chapter_id.value());
    Ok(true)
}
