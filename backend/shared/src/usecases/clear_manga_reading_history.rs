use anyhow::Result;

use crate::{
    database::Database,
    model::{ChapterState, MangaId},
};

use log::{info, warn};

pub async fn clear_manga_reading_history(db: &Database, manga_id: MangaId) -> Result<()> {
    let source_id = manga_id.source_id().value();
    let manga_id_details = manga_id.value();

    if source_id.trim().is_empty() || manga_id_details.trim().is_empty() {
        return Err(anyhow::anyhow!("Source ID or Manga ID cannot be empty"));
    }

    info!(
        "Clearing reading history for manga: {}-{}",
        manga_id_details, source_id
    );

    let chapter_informations = db.find_cached_chapter_informations(&manga_id).await;

    if chapter_informations.is_empty() {
        warn!(
            "No chapters found for manga: {}-{}",
            manga_id_details, source_id
        );
        return Ok(());
    }

    info!(
        "Found {} chapters for manga: {}-{}",
        chapter_informations.len(),
        manga_id_details,
        source_id
    );

    let unread_state = ChapterState { read: false };
    let mut read_count = 0u32;

    for chapter_info in &chapter_informations {
        if let Some(chapter_state) = db.find_chapter_state(&chapter_info.id).await {
            if chapter_state.read {
                read_count += 1;

                db.upsert_chapter_state(&chapter_info.id, unread_state)
                    .await;
            }
        }
    }

    info!(
        "Successfully cleared reading history for {} chapters in manga: {}:{}",
        read_count, source_id, manga_id_details
    );

    Ok(())
}
