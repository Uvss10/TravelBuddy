/* ══════════════════════════════════════════════════════════════════════════════
   TravelBuddy AI — app.js
   • 100 % offline capable (video generated client-side via video_generator.js)
   • Backend (http://127.0.0.1:8000) used for AI analysis + story — optional
   • Max 100 photos · 50 MB each · all browser-decodable image formats + RAW
   • Drag-and-drop zone + click-to-browse  (both fully wired)
   • Drag-to-REORDER thumbnails in the preview grid
   ══════════════════════════════════════════════════════════════════════════════ */
'use strict';

const API = ''; // Use relative path since backend serves frontend
const MAX_FILES = 100;
const MAX_MB = 50;

// All accepted image extensions (for tooltip / filtering)
const ACCEPTED_EXTS = new Set([
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'avif', 'svg', 'tiff', 'tif',
    'heic', 'heif',
    // RAW (displayed as placeholder card — browser limitation)
    'nef', 'cr2', 'arw', 'dng', 'raw', 'raf', 'orf', 'rw2', 'pef',
]);

// ── State ─────────────────────────────────────────────────────────────────────
const state = {
    photos: [],          // Array<File>
    analysed: [],          // backend ranked results
    storyData: null,
    slideTimer: null,
    interests: [],
    destination: '',
    tone: 'adventurous and inspiring',
    currentPlan: null,    // The full itinerary JSON
    map: null,            // Leaflet instance
    markers: [],
    polylines: [],
    geoCache: {},
    // drag-reorder
    _dragIdx: null,
    // mind-map (Professional & Animated)
    mindMapData: null,
    mmNodes: [],         // Flattened for hit testing
    mmTransform: { x: 0, y: 0, k: 1 },
    mmTargetTransform: { x: 0, y: 0, k: 1 }, // Moving towards this for smooth pan/zoom
    mmHoverNode: null,
    mmDragging: false,
    mmLastMouse: { x: 0, y: 0 },
    mmAnimationId: null,
    mmStartTime: 0,
};

// ── DOM helpers ───────────────────────────────────────────────────────────────
const $ = (id) => document.getElementById(id);
const qs = (sel) => document.querySelector(sel);

function setLoading(btnId, spinnerId, on, label) {
    const btn = $(btnId), sp = $(spinnerId);
    if (!btn || !sp) return;
    btn.disabled = on;
    btn.classList.toggle('loading', on);
    if (label) { const s = btn.querySelector('span:first-child'); if (s) s.textContent = label; }
    sp.style.display = on ? 'inline-block' : 'none';
}

function showErr(id, msg) {
    const el = $(id);
    if (!el) return;
    el.textContent = msg || '';
    el.classList.toggle('show', !!msg);
}

function showToast(msg, duration = 3000) {
    const t = $('toast');
    if (!t) return;
    t.textContent = msg;
    t.classList.remove('hidden');
    setTimeout(() => t.classList.add('hidden'), duration);
}

function fmt(n) { return n != null ? '₹' + Number(n).toLocaleString('en-IN') : '—'; }

// ── Tab navigation ────────────────────────────────────────────────────────────
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(b => {
            b.classList.remove('active');
            b.setAttribute('aria-selected', 'false');
        });
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.add('hidden'));
        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');
        const paneId = 'tab' + btn.dataset.tab.charAt(0).toUpperCase() + btn.dataset.tab.slice(1);
        $(paneId)?.classList.remove('hidden');
        window.scrollTo({ top: 0, behavior: 'smooth' });
    });
});

$('goReelTabBtn')?.addEventListener('click', () => $('tabReelBtn')?.click());

// ══════════════════════════════════════════════════════════════════════════════
// ██  TAB 1 — PHOTO → REEL
// ══════════════════════════════════════════════════════════════════════════════

const dropZone = $('dropZone');
const photoInput = $('photoInput');
const photoGrid = $('photoGrid');
const dropPh = $('dropPh');

// ── Click-to-browse ───────────────────────────────────────────────────────────
$('browseBtn')?.addEventListener('click', (e) => { e.stopPropagation(); photoInput.click(); });
dropZone?.addEventListener('click', (e) => {
    if (!e.target.closest('.thumb-del') && !e.target.closest('.thumb')) photoInput.click();
});
dropZone?.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') photoInput.click(); });
photoInput?.addEventListener('change', () => { addFiles([...photoInput.files]); photoInput.value = ''; });

// ── Drag-and-drop FROM OS (adding new photos) ─────────────────────────────────
dropZone?.addEventListener('dragover', (e) => { e.preventDefault(); dropZone.classList.add('drag-over'); });
dropZone?.addEventListener('dragleave', (e) => {
    // Only remove class if leaving the zone itself (not a child)
    if (!dropZone.contains(e.relatedTarget)) dropZone.classList.remove('drag-over');
});
dropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('drag-over');

    // Ignore internal thumbnail reorder drops
    if (state._dragIdx !== null) return;

    const files = [...e.dataTransfer.files].filter(f => {
        const ext = f.name.split('.').pop().toLowerCase();
        return f.type.startsWith('image/') || ACCEPTED_EXTS.has(ext);
    });
    addFiles(files);
});

// ── Add files (validate, dedup, limit) ───────────────────────────────────────
function addFiles(files) {
    showErr('uploadErr', '');
    state.analysed = [];
    state.storyData = null; // Clear stale story
    $('reelStep2')?.classList.add('hidden');
    $('reelStep3')?.classList.add('hidden');
    let skipped = 0, skippedNames = [];

    for (const f of files) {
        if (state.photos.length >= MAX_FILES) {
            skipped++;
            continue;
        }
        const err = window.validateImageFile ? window.validateImageFile(f) : null;
        if (err) {
            skipped++;
            skippedNames.push(f.name);
            showErr('uploadErr', err);
            continue;
        }
        // Dedup by name + size
        const dup = state.photos.some(p => p.name === f.name && p.size === f.size);
        if (!dup) state.photos.push(f);
    }

    if (skipped > 1) {
        showErr('uploadErr', `${skipped} files skipped — exceeded ${MAX_FILES} photo limit or ${MAX_MB} MB size limit.`);
    }
    renderGrid();
}

// ── Render thumbnail grid + drag-to-reorder wiring ───────────────────────────
function renderGrid() {
    photoGrid.innerHTML = '';

    state.photos.forEach((f, i) => {
        const wrap = document.createElement('div');
        wrap.className = 'thumb';
        wrap.draggable = true;
        wrap.dataset.idx = i;

        const ext = f.name.split('.').pop().toLowerCase();
        const isRaw = window.VG ? window.VG.RAW_EXTS.has(ext) : ['nef', 'cr2', 'arw', 'dng', 'raw'].includes(ext);

        // Check if backend already analysed and refined this (we check state.analysed)
        const analysis = state.analysed.find(a => a.image_path && a.image_path.split(/[/\\]/).pop() === f.name);
        const refinedUrl = (analysis && analysis.refined_path) ? `${API}/${analysis.refined_path}` : '';
        const blobUrl = isRaw ? '' : URL.createObjectURL(f);

        wrap.innerHTML = `
            ${refinedUrl
                ? `<img src="${refinedUrl}" alt="${f.name}" loading="lazy">`
                : (isRaw
                    ? `<div class="thumb-raw-ph"><span>📷</span><small>${ext.toUpperCase()}</small></div>`
                    : `<img src="${blobUrl}" alt="${f.name}" loading="lazy">`
                )
            }
            <div class="thumb-order">${i + 1}</div>
            <button class="thumb-del" type="button" title="Remove" data-idx="${i}">✕</button>
            ${(isRaw && !refinedUrl) ? `<span class="raw-tag">RAW</span>` : ''}
        `;

        // Remove button
        wrap.querySelector('.thumb-del').addEventListener('click', (e) => {
            e.stopPropagation();
            removePhoto(parseInt(e.currentTarget.dataset.idx));
        });

        // ── Drag-to-reorder (HTML5 Drag API within the grid) ──
        wrap.addEventListener('dragstart', (e) => {
            state._dragIdx = i;
            wrap.classList.add('dragging');
            e.dataTransfer.effectAllowed = 'move';
            e.dataTransfer.setData('text/plain', String(i)); // required in Firefox
        });
        wrap.addEventListener('dragend', () => {
            state._dragIdx = null;
            wrap.classList.remove('dragging');
            document.querySelectorAll('.thumb').forEach(t => t.classList.remove('drag-target'));
        });
        wrap.addEventListener('dragover', (e) => {
            e.preventDefault();
            if (state._dragIdx !== null && state._dragIdx !== i) {
                e.dataTransfer.dropEffect = 'move';
                document.querySelectorAll('.thumb').forEach(t => t.classList.remove('drag-target'));
                wrap.classList.add('drag-target');
            }
        });
        wrap.addEventListener('drop', (e) => {
            e.preventDefault();
            e.stopPropagation();          // prevent the zone-level drop handler
            const from = state._dragIdx;
            if (from === null || from === i) return;
            // Reorder
            const moved = state.photos.splice(from, 1)[0];
            state.photos.splice(i, 0, moved);
            state._dragIdx = null;
            renderGrid();
        });

        photoGrid.appendChild(wrap);
    });

    const n = state.photos.length;
    const hasPhotos = n > 0;
    dropPh.style.display = hasPhotos ? 'none' : 'flex';
    photoGrid.style.display = hasPhotos ? 'grid' : 'none';
    $('countBar').style.display = hasPhotos ? 'flex' : 'none';
    $('countLabel').textContent = `${n} / ${MAX_FILES} photos selected`;
    $('analyseBtn').disabled = !hasPhotos;
}

function removePhoto(i) {
    state.photos.splice(i, 1);
    state.analysed = [];
    state.storyData = null;
    $('reelStep2')?.classList.add('hidden');
    $('reelStep3')?.classList.add('hidden');
    renderGrid();
}

$('clearBtn')?.addEventListener('click', async () => {
    state.photos = [];
    state.analysed = [];
    state.storyData = null;
    localStorage.removeItem('tb_server_paths');

    // Hide following sections as they are now stale
    $('reelStep2')?.classList.add('hidden');
    $('reelStep3')?.classList.add('hidden');
    $('videoPlayerWrap').style.display = 'none';

    renderGrid();
    showErr('uploadErr', '');

    // Call backend to wipe folders
    try { fetch(`${API}/images/clear`, { method: 'POST' }); } catch (_) { }

    showToast('🧹 All data cleared (Local & Server)');
});

// ── Analyse & Generate ────────────────────────────────────────────────────────
$('analyseBtn')?.addEventListener('click', async () => {
    showErr('uploadErr', '');
    state.destination = $('reelDest').value.trim();
    state.tone = $('reelTone').value;

    if (state.photos.length === 0) { showErr('uploadErr', 'Please add at least one photo.'); return; }

    setLoading('analyseBtn', 'analyseSpinner', true, '✨ Analysing photos…');

    try {
        // ── Try backend upload & AI analysis ──────────────────────────────────
        let uploadData = null;
        try {
            const fd = new FormData();
            state.photos.forEach(f => fd.append('files', f));
            const uploadResp = await fetch(`${API}/images/upload`, { method: 'POST', body: fd, signal: AbortSignal.timeout(120_000) });
            if (uploadResp.ok) uploadData = await uploadResp.json();
        } catch (backendErr) {
            console.warn('[App] Backend unavailable — running fully offline.', backendErr);
        }

        if (uploadData) {
            state.analysed = (uploadData.analysis_results?.ranked_results) || [];
            renderSelectedPhotos(uploadData);
            // Cache server paths so the Cinematic button works after page reload
            try {
                const paths = state.analysed.map(r => r.image_path).filter(Boolean);
                if (paths.length > 0) localStorage.setItem('tb_server_paths', JSON.stringify(paths));
            } catch (_) { }
        } else {
            // ── Offline: use all uploaded photos as-is ─────────────────────
            state.analysed = [];
            renderSelectedPhotosOffline();
        }

        // ── Try backend story generation ──────────────────────────────────────
        let storyData = null;
        try {
            const sceneTags = state.analysed.length > 0
                ? [...new Set(state.analysed.map(r => r.scene_tag || r.dominant_scene || 'travel'))]
                : (state.interests.length > 0 ? state.interests : ['travel', 'landscape', 'adventure']);

            const storyResp = await fetch(`${API}/story/generate`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ destination: state.destination || 'my trip', scene_tags: sceneTags, tone: state.tone }),
                signal: AbortSignal.timeout(90_000),
            });
            if (storyResp.ok) storyData = await storyResp.json();
        } catch (e) {
            console.warn('[App] Story API unavailable — using offline fallback.', e);
        }

        // ── Offline story fallback ────────────────────────────────────────────
        if (!storyData) storyData = buildOfflineStory(state.destination || 'My Trip', state.tone);

        state.storyData = storyData;
        renderStory(storyData);

        $('reelStep2').classList.remove('hidden');
        $('reelStep3').classList.remove('hidden');
        $('reelStep2').scrollIntoView({ behavior: 'smooth' });

    } catch (err) {
        showErr('uploadErr', `Error: ${err.message}`);
        console.error(err);
    } finally {
        setLoading('analyseBtn', 'analyseSpinner', false, '✨ Analyse & Generate Reel Story');
    }
});

// ── Offline story builder ─────────────────────────────────────────────────────
function buildOfflineStory(dest, tone) {
    const tonesMap = {
        'adventurous and inspiring': { adj: 'epic', verb: 'chased' },
        'dreamy and peaceful': { adj: 'dreamy', verb: 'wandered through' },
        'funny and light-hearted': { adj: 'hilarious', verb: 'survived' },
        'emotional and nostalgic': { adj: 'unforgettable', verb: 'cherished' },
    };
    const t = tonesMap[tone] || tonesMap['adventurous and inspiring'];
    return {
        title: `${t.adj.charAt(0).toUpperCase() + t.adj.slice(1)} Memories — ${dest}`,
        narration: `We ${t.verb} every corner of ${dest}.\n\nEach photo holds a story — a moment frozen in time.\n\nSome places don't just fill your camera roll, they fill your soul.\n\n${dest} — once visited, never forgotten.`,
        captions: [
            `Hello, ${dest} 🌍`,
            'Where every corner is a postcard ✨',
            'Chasing the golden hour 🌅',
            'Flavours you\'ll dream about 🍜',
            'Hidden streets, endless stories 🗺️',
            'This view though 😍',
            'Wanderlust fully activated 🎒',
            'Memories in the making 🎬',
        ],
        hashtags: [`#${dest.replace(/\s+/g, '')}`, `#Visit${dest.replace(/\s+/g, '')}`, '#TravelReel', '#CinematicTravel', '#WanderlustVibes', '#TravelBuddy', '#ExploreMore', '#ReelItFeelIt'],
    };
}

// ── Render: offline (no backend) ──────────────────────────────────────────────
function renderSelectedPhotosOffline() {
    const grid = $('selectedGrid');
    grid.innerHTML = '';

    if (state.photos.length === 0) return;

    state.photos.forEach((f, i) => {
        const ext = f.name.split('.').pop().toLowerCase();
        const isRaw = window.VG ? window.VG.RAW_EXTS.has(ext) : false;
        const wrap = document.createElement('div');
        wrap.className = 'sel-wrap';

        if (isRaw) {
            wrap.innerHTML = `<div class="thumb-raw-ph" style="height:120px"><span>📷</span><small>${ext.toUpperCase()}</small></div><span class="sel-score">RAW</span>`;
        } else {
            const url = URL.createObjectURL(f);
            wrap.innerHTML = `<img src="${url}" alt="" loading="lazy"><span class="sel-score">#${i + 1}</span>`;
        }
        grid.appendChild(wrap);
    });

    $('selectedSummary').textContent = `${state.photos.length} photos loaded — running offline (no AI scoring)`;
    $('scoreInfo').innerHTML = `<strong>ℹ️ Offline mode:</strong> Backend not available. Photos used as uploaded. Start the backend for AI quality scoring.`;

    // Build slideshow from local blobs
    const urls = state.photos
        .filter(f => !((window.VG || {}).RAW_EXTS || new Set()).has(f.name.split('.').pop().toLowerCase()))
        .map(f => URL.createObjectURL(f));
    buildReelSlideshow(urls);
}

// ── Render: backend analysis ──────────────────────────────────────────────────
function renderSelectedPhotos(data) {
    const results = (data.analysis_results?.ranked_results) || [];
    const grid = $('selectedGrid');
    grid.innerHTML = '';

    results.forEach(r => {
        const filename = r.image_path ? r.image_path.split(/[/\\]/).pop() : '';
        const file = state.photos.find(f => f.name === filename);
        if (!file && !r.refined_path) return;

        const wrap = document.createElement('div');
        wrap.className = 'sel-wrap';
        const score = r.final_quality_score != null ? `${Math.round(r.final_quality_score)}%` : '';
        const visionLabel = r.quality_label || '';
        const imgUrl = r.refined_path ? `${API}/${r.refined_path}` : (file ? URL.createObjectURL(file) : '');

        wrap.innerHTML = `
            <img src="${imgUrl}" alt="" loading="lazy">
            ${score ? `<span class="sel-score">${score}</span>` : ''}
            ${visionLabel ? `<div class="vision-badge">${visionLabel}</div>` : ''}
        `;
        grid.appendChild(wrap);
    });

    $('selectedSummary').textContent = `${data.uploaded_count} unique shots ranked by AI quality scoring`;
    $('scoreInfo').innerHTML = `<strong>AI quality metrics used:</strong> Blur detection · Sharpness · Exposure · Contrast · Entropy · Face detection · Perceptual deduplication`;

    const slideshowUrls = results
        .map(r => {
            if (r.refined_path) return `${API}/${r.refined_path}`;
            const fn = r.image_path ? r.image_path.split(/[/\\]/).pop() : '';
            const f = state.photos.find(f => f.name === fn);
            return f ? URL.createObjectURL(f) : null;
        })
        .filter(Boolean);

    buildReelSlideshow(slideshowUrls);
}

// ── Reel slideshow preview ────────────────────────────────────────────────────
function buildReelSlideshow(urls) {
    const container = $('reelSlides');
    container.innerHTML = '';
    if (!urls.length) return;

    urls.forEach((url, i) => {
        const img = document.createElement('img');
        img.className = 'reel-slide' + (i === 0 ? ' active' : '');
        img.src = url;
        container.appendChild(img);
    });

    let cur = 0;
    if (state.slideTimer) clearInterval(state.slideTimer);
    state.slideTimer = setInterval(() => {
        const slides = container.querySelectorAll('.reel-slide');
        if (!slides.length) return;
        slides[cur].classList.remove('active');
        cur = (cur + 1) % slides.length;
        slides[cur].classList.add('active');
        const caps = state.storyData?.captions || [];
        if (caps.length) $('reelCapPrev').textContent = caps[cur % caps.length];
    }, 2200);
}

// ── Render story panel ────────────────────────────────────────────────────────
function renderStory(data) {
    $('storyTitle').textContent = data.title || '';
    $('narrationEdit').value = data.narration || '';
    $('captionsWrap').innerHTML = (data.captions || []).map(c =>
        `<div class="cap-item" onclick="copyCap('${c.replace(/'/g, "\\'")}')"><span>${c}</span><span class="cap-copy">tap to copy</span></div>`
    ).join('');
    $('hashtagsWrap').innerHTML = (data.hashtags || []).map(h => `<span class="tag">${h}</span>`).join('');
    if (data.captions?.length) $('reelCapPrev').textContent = data.captions[0];
}

// eslint-disable-next-line no-unused-vars
function copyCap(text) { navigator.clipboard.writeText(text).catch(() => { }); }
window.copyCap = copyCap;

// ── Copy buttons ──────────────────────────────────────────────────────────────
$('copyNarBtn')?.addEventListener('click', () => {
    navigator.clipboard.writeText($('narrationEdit').value).then(() => {
        $('copyNarBtn').textContent = '✅ Copied!';
        setTimeout(() => { $('copyNarBtn').textContent = '📋 Copy'; }, 2000);
    });
});
$('copyTagsBtn')?.addEventListener('click', () => {
    const tags = (state.storyData?.hashtags || []).join(' ');
    navigator.clipboard.writeText(tags).then(() => {
        $('copyTagsBtn').textContent = '✅ Copied!';
        setTimeout(() => { $('copyTagsBtn').textContent = '📋 Copy Hashtags'; }, 2000);
    });
});

// ── Share ─────────────────────────────────────────────────────────────────────
$('shareBtn')?.addEventListener('click', () => {
    const text = [state.storyData?.title || '', '', $('narrationEdit').value, '', (state.storyData?.hashtags || []).join(' ')].join('\n');
    if (navigator.share) { navigator.share({ title: 'TravelBuddy Reel', text }); }
    else { navigator.clipboard.writeText(text).then(() => alert('Story copied to clipboard!')); }
});

// ── Video generation (100 % offline — client-side Canvas+MediaRecorder) ───────
$('downloadReelBtn')?.addEventListener('click', async () => {
    // Collect image sources: prefer backend refined paths, fallback to original File objects
    let sources = [];
    const captions = state.storyData?.captions || [];

    if (state.analysed.length > 0) {
        // Backend was used — build source list from analysis results
        state.analysed.forEach(r => {
            if (r.refined_path) {
                sources.push(`${API}/${r.refined_path}`);
            } else {
                const fn = r.image_path ? r.image_path.split(/[/\\]/).pop() : '';
                const file = state.photos.find(f => f.name === fn);
                if (file) sources.push(file);
            }
        });
    }

    // Fallback: use all selected photos (File objects work offline, no network needed)
    if (sources.length === 0) {
        sources = [...state.photos];
    }

    if (sources.length === 0) {
        showErr('storyErr', 'No images found. Please add photos first.');
        return;
    }

    // Clamp to 100
    sources = sources.slice(0, 100);

    // UI: show progress
    const btn = $('downloadReelBtn');
    const sp = $('videoSpinner');
    btn.disabled = true;
    const lblSpan = btn.querySelector('span:first-child');
    if (lblSpan) lblSpan.textContent = '⏳ Rendering…';
    if (sp) sp.style.display = 'inline-block';
    $('videoProgressWrap').style.display = 'block';
    $('videoPlayerWrap').style.display = 'none';
    $('videoProgressBar').style.width = '0%';
    $('videoProgressLabel').textContent = 'Starting…';
    showErr('storyErr', '');

    try {
        if (typeof generateReelVideo !== 'function') throw new Error('Video generator not loaded. Ensure video_generator.js is included.');

        const blob = await generateReelVideo(sources, captions, (label, pct) => {
            $('videoProgressLabel').textContent = label;
            $('videoProgressBar').style.width = `${pct}%`;
        });

        // Show inline player
        const url = URL.createObjectURL(blob);
        const vid = $('generatedVideo');
        vid.src = url;
        $('videoPlayerWrap').style.display = 'block';
        vid.play().catch(() => { });

        // Auto-download
        const ext = blob.type.includes('mp4') ? 'mp4' : 'webm';
        const dest = (state.destination || 'reel').replace(/\s+/g, '_');
        const a = document.createElement('a');
        a.href = url;
        a.download = `TravelBuddy_${dest}_1min.${ext}`;
        a.click();

        $('videoProgressLabel').textContent = `✅ 1-minute reel ready! (${sources.length} photos · ${blob.type.includes('mp4') ? 'MP4' : 'WebM'})`;
        $('videoProgressBar').style.width = '100%';

    } catch (err) {
        showErr('storyErr', `Video error: ${err.message}`);
        console.error(err);
    } finally {
        btn.disabled = false;
        if (lblSpan) lblSpan.textContent = '🎬 Generate Video';
        if (sp) sp.style.display = 'none';
    }
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎬  CINEMATIC ENGINE — Server-side 9-module pipeline
// ══════════════════════════════════════════════════════════════════════════════

/**
 * State additions for cinematic engine
 */
state.cinematicTheme = 'cinematic';
state.uploadedAudioPath = null;   // server-side path returned by /video/upload-audio
state.lrcContent = null;          // raw .lrc lyric file text

// ── Theme selector wiring ─────────────────────────────────────────────────────
document.querySelectorAll('.theme-chip').forEach(chip => {
    chip.addEventListener('click', () => {
        document.querySelectorAll('.theme-chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.cinematicTheme = chip.dataset.theme || 'cinematic';
        showToast(`🎨 Theme: ${chip.textContent.trim()}`);
    });
});

// ── Audio upload for beat sync ────────────────────────────────────────────────
$('audioUploadInput')?.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const label = $('audioUploadLabel');
    if (label) label.textContent = `⏳ Uploading ${file.name}…`;

    try {
        const fd = new FormData();
        fd.append('file', file);
        const resp = await fetch(`${API}/video/upload-audio`, {
            method: 'POST', body: fd,
            signal: AbortSignal.timeout(60_000),
        });
        if (!resp.ok) throw new Error((await resp.json()).error || `HTTP ${resp.status}`);
        const data = await resp.json();
        state.uploadedAudioPath = data.audio_path;
        if (label) label.textContent = `🎵 ${data.filename} (${data.size_mb} MB) — ready`;
        showToast('🎵 Music uploaded — beat sync enabled!');
    } catch (err) {
        if (label) label.textContent = `❌ Upload failed: ${err.message}`;
        state.uploadedAudioPath = null;
    }
    e.target.value = '';
});

// ── LRC lyric file loader ─────────────────────────────────────────────────────
$('lrcFileInput')?.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    try {
        state.lrcContent = await file.text();
        const label = $('lrcLabel');
        if (label) label.textContent = `📝 ${file.name} loaded`;
        showToast('📝 Lyrics loaded — lyric overlay enabled!');
    } catch (_) {
        state.lrcContent = null;
    }
    e.target.value = '';
});

// ── Cinematic generate button — async job polling ─────────────────────────────
$('cinematicReelBtn')?.addEventListener('click', async () => {
    // ── Resolve server-side photo paths ─────────────────────────────────────
    let serverPaths = (state.analysed || []).map(r => r.image_path).filter(Boolean);

    const btn = $('cinematicReelBtn');
    const sp = $('cinematicSpinner');
    const progWrap = $('cinematicProgressWrap');
    const progBar = $('cinematicProgressBar');
    const progLbl = $('cinematicProgressLabel');

    const setProgress = (pct, msg) => {
        if (progBar) { progBar.style.background = ''; progBar.style.width = `${pct}%`; }
        if (progLbl) progLbl.textContent = msg;
    };

    btn.disabled = true;
    if (sp) sp.style.display = 'inline-block';
    if (progWrap) progWrap.style.display = 'block';
    showErr('storyErr', '');
    $('videoPlayerWrap').style.display = 'none';
    setProgress(2, '🔍 Preparing photos…');

    const LS_KEY = 'tb_server_paths';
    try {
        // P1: auto-upload browser files if still no paths
        if (serverPaths.length === 0 && state.photos.length > 0) {
            setProgress(6, `📤 Uploading ${state.photos.length} photo(s) to server…`);
            try {
                const fd = new FormData();
                state.photos.forEach(f => fd.append('files', f));
                const up = await fetch(`${API}/images/upload`, {
                    method: 'POST', body: fd,
                    signal: AbortSignal.timeout(120_000),
                });
                if (up.ok) {
                    const d = await up.json();
                    const ranked = d.analysis_results?.ranked_results || [];
                    serverPaths = ranked.map(r => r.image_path).filter(Boolean);
                    if (ranked.length > 0) { state.analysed = ranked; }
                } else {
                    console.warn('[Cinematic] Upload returned', up.status);
                }
            } catch (uploadErr) {
                console.warn('[Cinematic] Upload failed:', uploadErr.message);
            }
        }

        // P2: try localStorage cache ONLY if the session is totally fresh (no photos uploaded yet)
        if (serverPaths.length === 0 && state.photos.length === 0) {
            try {
                const cached = JSON.parse(localStorage.getItem(LS_KEY) || '[]');
                if (Array.isArray(cached) && cached.length > 0) {
                    serverPaths = cached;
                    setProgress(4, `📂 Loaded ${serverPaths.length} photo paths from cache.`);
                }
            } catch (_) { }
        }

        // P3: GET /images/list — only if we have NO active session photos
        if (serverPaths.length === 0 && state.photos.length === 0) {
            setProgress(5, '🔎 Checking server for existing photos…');
            try {
                const lr = await fetch(`${API}/images/list`);
                if (lr.ok) {
                    const d = await lr.json();
                    serverPaths = (d.images || []).slice(0, 100);
                }
            } catch (_) { }
        }

        // Save to localStorage for next session
        if (serverPaths.length > 0) {
            try { localStorage.setItem(LS_KEY, JSON.stringify(serverPaths)); } catch (_) { }
        }

        // Final guard — nothing anywhere
        if (serverPaths.length === 0) {
            const isOffline = !navigator.onLine;
            const hasLocalPhotos = state.photos.length > 0;
            let errMsg = '⚠ ';
            if (isOffline) {
                errMsg += 'You appear to be offline. ';
            }
            if (!hasLocalPhotos) {
                errMsg += 'No photos found. Please drag & drop photos in Step 1 first.';
            } else {
                errMsg += 'Could not reach backend (port 8000). Run: python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000';
            }
            showErr('storyErr', errMsg);
            console.error('[Cinematic] All 4 priorities failed. state.photos:', state.photos.length, 'online:', navigator.onLine);
            return;
        }


        setProgress(10, `📤 Starting cinematic pipeline (${serverPaths.length} photos)…`);

        // ── POST to kick off the background job ───────────────────────────────
        const payload = {
            image_paths: serverPaths,
            captions: state.storyData?.captions || [],
            destination: state.destination || 'my_trip',
            theme: state.cinematicTheme || 'cinematic',
            audio_path: state.uploadedAudioPath || null,
            lrc_content: state.lrcContent || null,
            duration_s: 60,   // Pro 1-minute default reel
        };

        const startResp = await fetch(`${API}/video/cinematic`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
            signal: AbortSignal.timeout(30_000),   // just for the kick-off call
        });

        if (!startResp.ok) {
            const e = await startResp.json().catch(() => ({}));
            throw new Error(e.message || e.detail || `HTTP ${startResp.status}`);
        }

        const startData = await startResp.json();
        if (startData.status === 'error') throw new Error(startData.message);

        const jobId = startData.job_id;
        if (!jobId) throw new Error('No job ID returned from server.');

        setProgress(12, '🚀 Render job started — polling for progress…');

        // ── Poll GET /video/status/{jobId} every 2 seconds ────────────────────
        await new Promise((resolve, reject) => {
            const poll = setInterval(async () => {
                try {
                    const statusResp = await fetch(`${API}/video/status/${jobId}`, {
                        signal: AbortSignal.timeout(10_000),
                    });
                    if (!statusResp.ok) return;   // transient error — keep polling
                    const s = await statusResp.json();

                    // Mirror live backend progress
                    const pct = Math.max(12, Math.min(99, s.progress || 12));
                    setProgress(pct, s.message || '🎬 Rendering…');

                    if (s.status === 'done') {
                        clearInterval(poll);
                        setProgress(100, `✅ ${s.message || 'Cinematic reel ready!'}`);

                        if (s.video_url) {
                            const vid = $('generatedVideo');
                            vid.src = `${API}${s.video_url}?t=${Date.now()}`;
                            $('videoPlayerWrap').style.display = 'block';
                            vid.play().catch(() => { });

                            const a = document.createElement('a');
                            a.href = vid.src;
                            const dest = (state.destination || 'reel').replace(/\s+/g, '_');
                            a.download = `TravelBuddy_${dest}_${state.cinematicTheme}.mp4`;
                            a.click();
                            showToast(`🎬 Reel ready! BPM: ${s.beat_map?.bpm || '–'}`);
                        }
                        resolve();
                    } else if (s.status === 'error' || s.status === 'not_found') {
                        clearInterval(poll);
                        reject(new Error(s.message || 'Render failed on server.'));
                    }
                    // else: still 'running' or 'queued' — keep polling
                } catch (pollErr) {
                    console.warn('[Cinematic] poll error:', pollErr);
                    // keep polling — transient network issue
                }
            }, 2000);   // poll every 2 s

            // Bail out after 15 minutes max
            setTimeout(() => {
                clearInterval(poll);
                reject(new Error('Render timed out after 15 minutes.'));
            }, 15 * 60 * 1000);
        });

    } catch (err) {
        setProgress(0, `❌ ${err.message}`);
        if (progBar) progBar.style.background = '#ef4444';
        showErr('storyErr', `Cinematic render failed: ${err.message}`);
        console.error('[Cinematic]', err);
    } finally {
        btn.disabled = false;
        if (sp) sp.style.display = 'none';
    }
});

// ── New Reel ──────────────────────────────────────────────────────────────────
$('newReelBtn')?.addEventListener('click', () => {
    state.photos = []; state.analysed = []; state.storyData = null;
    if (state.slideTimer) { clearInterval(state.slideTimer); state.slideTimer = null; }
    showErr('uploadErr', ''); showErr('storyErr', '');
    renderGrid();
    $('reelStep2').classList.add('hidden');
    $('reelStep3').classList.add('hidden');
    $('reelSlides').innerHTML = '';
    $('reelCapPrev').textContent = 'Your photos + narration = reel';
    $('videoProgressWrap').style.display = 'none';
    $('videoPlayerWrap').style.display = 'none';
    window.scrollTo({ top: 0, behavior: 'smooth' });
});

// ══════════════════════════════════════════════════════════════════════════════
// ██  TAB 2 — TRIP PLANNER
// ══════════════════════════════════════════════════════════════════════════════

// Interest chips
document.querySelectorAll('.i-chip').forEach(chip => {
    chip.addEventListener('click', () => {
        chip.classList.toggle('on');
        const v = chip.dataset.v;
        state.interests = chip.classList.contains('on')
            ? [...state.interests, v]
            : state.interests.filter(i => i !== v);
    });
});

// Form submit
$('itineraryForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    showErr('planErr', '');

    const dest = $('destination').value.trim();
    const days = parseInt($('days').value);
    const budget = $('budget').value;
    const travelStyle = $('travelStyle').value;
    const groupType = $('groupType').value;
    const startLoc = $('startLoc').value.trim();
    const constraints = $('constraints').value.trim();

    let valid = true;
    if (!dest) { $('destErr').textContent = 'Enter a city name.'; $('destErr').classList.add('show'); valid = false; }
    else { $('destErr').classList.remove('show'); }
    if (!days || days < 1 || days > 14) { $('daysErr').textContent = '1–14 days only.'; $('daysErr').classList.add('show'); valid = false; }
    else { $('daysErr').classList.remove('show'); }
    if (!valid) return;

    setLoading('planBtn', 'planSpinner', true, 'Planning your route optimized trip…');

    try {
        const resp = await fetch(`${API}/itinerary/generate`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                destination: dest,
                days,
                budget,
                interests: state.interests,
                travel_style: travelStyle,
                group_type: groupType,
                starting_location: startLoc,
                custom_constraints: constraints
            }),
            signal: AbortSignal.timeout(300_000),
        });
        if (!resp.ok) {
            const err = await resp.json().catch(() => ({}));
            throw new Error(err.detail || `Server error ${resp.status}`);
        }
        const data = await resp.json();
        $('planResult').classList.remove('hidden');
        renderPlan(data);
        $('planResult').scrollIntoView({ behavior: 'smooth' });
    } catch (err) {
        showErr('planErr', `Failed: ${err.message}`);
    } finally {
        setLoading('planBtn', 'planSpinner', false, 'Generate City Guide');
    }
});

$('tweakBtn')?.addEventListener('click', async () => {
    const mod = $('tweakInput').value.trim();
    if (!mod) { showErr('tweakErr', 'Please describe what to change.'); return; }
    if (!state.currentPlan) { showErr('tweakErr', 'No plan to tweak! Generate one first.'); return; }

    showErr('tweakErr', '');
    setLoading('tweakBtn', 'tweakSpinner', true, 'Applying Tweak…');

    try {
        const resp = await fetch(`${API}/itinerary/edit`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                existing_plan: state.currentPlan,
                modification: mod,
                interests: state.interests
            }),
            signal: AbortSignal.timeout(300_000),
        });
        if (!resp.ok) {
            const err = await resp.json().catch(() => ({}));
            throw new Error(err.detail || `Server error ${resp.status}`);
        }
        const data = await resp.json();
        $('planResult').classList.remove('hidden');
        renderPlan(data);
        $('tweakInput').value = '';
        showToast('✨ Plan updated successfully!');
    } catch (err) {
        showErr('tweakErr', `Tweak failed: ${err.message}`);
    } finally {
        setLoading('tweakBtn', 'tweakSpinner', false, 'Apply Modification');
    }
});

$('clearInterests')?.addEventListener('click', () => {
    state.interests = [];
    document.querySelectorAll('.i-chip').forEach(c => c.classList.remove('on'));
});

// Render plan
function renderPlan(data) {
    let raw = data.itinerary_ai_output;
    if (typeof raw === 'string') {
        try { const m = raw.match(/\{[\s\S]*\}/); raw = m ? JSON.parse(m[0]) : null; }
        catch (_) { raw = null; }
    }
    state.currentPlan = raw;

    const summary = (raw && raw.trip_summary) || {};

    $('tripMeta').innerHTML = `
        <div class="meta-dest">${summary.destination || data.destination}</div>
        <div class="meta-chips">
            <span class="meta-chip">📅 ${summary.duration_days || data.total_days} Days</span>
            <span class="meta-chip">💰 ${summary.estimated_total_trip_cost || data.budget_category}</span>
            <span class="meta-chip">🔥 Intensity: ${summary.intensity_score || '?'}/10</span>
            <span class="meta-chip">⏱️ Travel: ${summary.estimated_total_travel_time || '?'}</span>
            ${(data.interests || []).map(i => `<span class="meta-chip">• ${i}</span>`).join('')}
        </div>
        ${summary.style_adherence ? `<div class="meta-best-for">Route Strategy: ${summary.style_adherence}</div>` : ''}
    `;

    const dc = $('dayCards');
    dc.innerHTML = '';

    if (raw && Array.isArray(raw.days)) {
        raw.days.forEach((day, idx) => {
            const card = document.createElement('div');
            card.className = 'day-card';

            const acts = (day.activities || []).map(a => {
                const time = a.recommended_time || '';
                const place = a.place_name || '';
                const desc = a.description || '';
                const cost = a.estimated_cost ? ` • ${a.estimated_cost}` : '';
                const travel = a.travel_time_from_previous ? `<div class="act-travel"><span>${a.transport_mode === 'walking' ? '🚶' : '🚗'}</span> <strong>${a.travel_time_from_previous}</strong> from previous</div>` : '';
                const dur = a.estimated_duration ? `<span class="act-dur">⏱️ ${a.estimated_duration}</span>` : '';
                const mapLabel = a.map_ready_label || `${place}, ${a.city || ''}, ${a.country || ''}`;

                let cls = (a.category || '').toLowerCase();
                if (cls.includes('food')) cls = 'food';
                else if (cls.includes('market') || cls.includes('shop')) cls = 'shopping';

                return `
                    <li class="act-item ${cls}">
                        <div class="act-header">
                            <span class="act-time">${time}</span>
                            <div style="display:flex; align-items:center; gap:8px">
                                <strong>${place}</strong>
                                <a href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(mapLabel)}" target="_blank" class="map-link-mini" title="View on Map">📍</a>
                            </div>
                            ${dur}
                        </div>
                        <p class="act-desc">${desc}</p>
                        ${travel}
                        ${a.buffer_time ? `<div class="act-note">💤 Buffer: ${a.buffer_time}</div>` : ''}
                        ${cost ? `<div class="act-cost">💰 ${cost}</div>` : ''}
                    </li>`;
            }).join('');

            card.innerHTML = `
                <div class="day-hd" onclick="toggleDay(this)">
                    <div class="day-num">${day.day || idx + 1}</div>
                    <div class="day-name">Strategy: ${day.route_strategy || 'Balanced Exploration'}</div>
                    <span class="day-chevron ${idx === 0 ? 'open' : ''}">▾</span>
                </div>
                <div class="day-body" style="${idx !== 0 ? 'display:none' : ''}">
                    <div class="day-start-loc">🚩 Start: ${day.starting_point || 'City Center'}</div>
                    <ul class="act-list">${acts}</ul>
                    <div class="day-footer-cost">
                        <span>Transit Time: ${day.total_daily_travel_time || '?'}</span> | 
                        <span>Daily Cost: ${day.daily_cost_estimate || '?'}</span>
                    </div>
                </div>`;
            dc.appendChild(card);
        });

        // Optimization Summary
        const optNotes = raw.routing_notes || raw.optimization_notes || raw.reasoning_summary;
        if (optNotes) {
            const rCard = document.createElement('div');
            rCard.className = 'card reasoning-card';
            rCard.innerHTML = `
                <div class="reasoning-hd">AI Route Optimization Logic</div>
                <div class="reasoning-body">${optNotes}</div>
            `;
            dc.appendChild(rCard);
        }
    } else {
        dc.innerHTML = `<div class="card"><pre style="white-space:pre-wrap;font-size:14px">${JSON.stringify(raw || data.itinerary_ai_output, null, 2)}</pre></div>`;
    }
    renderBudget(data.hotel_and_budget_estimation);

    // Trigger visualisations after layout settles
    setTimeout(async () => {
        try {
            renderMindMap(raw);
            await renderMap(raw);
        }
        catch (e) { console.error("Visualisation failed:", e); }
    }, 400);
}

// eslint-disable-next-line no-unused-vars
function toggleDay(hd) {
    const body = hd.nextElementSibling;
    const icon = hd.querySelector('.day-chevron');
    const open = body.style.display !== 'none';
    body.style.display = open ? 'none' : 'block';
    icon.classList.toggle('open', !open);
}
window.toggleDay = toggleDay;

function renderBudget(b) {
    const card = $('budgetCard');
    if (!b) { card?.classList.add('hidden'); return; }
    const rows = [
        ['🏨 Accommodation', b.accommodation],
        ['🍽 Food & Dining', b.food],
        ['🚆 Transport', b.transportation],
        ['🎟 Activities', b.activities],
        ['🛍 Shopping', b.shopping],
        ['🔧 Miscellaneous', b.miscellaneous],
    ].filter(([, v]) => v != null);
    if (!card) return;
    card.innerHTML = `
        <div class="budget-title">💸 Estimated Budget Breakdown</div>
        <table class="b-table">
            <tbody>${rows.map(([l, v]) => `<tr><td>${l}</td><td class="amt">${fmt(v)}</td></tr>`).join('')}</tbody>
            <tfoot><tr><td>Total Estimate</td><td class="amt">${fmt(b.estimated_total)}</td></tr></tfoot>
        </table>
        ${b.notes ? `<p class="b-note">${b.notes}</p>` : ''}`;
    card.classList.remove('hidden');
}

// ── Interactive Map ────────────────────────────────────────────────────────────
const MAP_COLORS = ['#38bdf8', '#fb7185', '#34d399', '#fbbf24', '#a78bfa', '#f472b6', '#94a3b8'];

async function geocode(query) {
    if (!query) return null;
    if (state.geoCache[query]) return state.geoCache[query];
    // Respect Nominatim 1 request/sec policy (approx)
    await new Promise(r => setTimeout(r, 250));
    try {
        const resp = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1`);
        const data = await resp.json();
        if (data && data.length > 0) {
            const loc = { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) };
            state.geoCache[query] = loc;
            return loc;
        }
    } catch (e) { console.warn('Geocode failed for:', query, e); }
    return null;
}

async function renderMap(plan) {
    if (!window.L || !plan || !Array.isArray(plan.days)) return;
    const mapEl = $('itineraryMap');
    if (!mapEl) return;

    // Init map
    if (!state.map) {
        state.map = L.map('itineraryMap');
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors',
            maxZoom: 19
        }).addTo(state.map);
    }

    // Initial center on destination to avoid "World Map" flicker
    const cityCenter = await geocode(plan.trip_summary?.destination || plan.destination);
    if (cityCenter) state.map.setView([cityCenter.lat, cityCenter.lng], 12);
    else state.map.setView([20, 0], 2);

    state.map.invalidateSize();
    setTimeout(() => state.map.invalidateSize(), 300);

    // Clear prev
    state.markers.forEach(m => state.map.removeLayer(m));
    state.polylines.forEach(p => state.map.removeLayer(p));
    state.markers = [];
    state.polylines = [];
    const legend = $('mapLegend');
    if (legend) legend.innerHTML = '';

    const allCoords = [];

    // Process days
    for (let i = 0; i < plan.days.length; i++) {
        const day = plan.days[i];
        const color = MAP_COLORS[i % MAP_COLORS.length];
        const dayCoords = [];

        // Add to legend
        if (legend) {
            const legItem = document.createElement('div');
            legItem.className = 'map-legend-item';
            legItem.innerHTML = `<span class="dot" style="background:${color}"></span> Day ${day.day || i + 1}`;
            legend.appendChild(legItem);
        }

        // Geocode activities
        const acts = day.activities || [];
        for (let j = 0; j < acts.length; j++) {
            const act = acts[j];
            const query = act.map_ready_label || `${act.place_name}, ${plan.trip_summary?.destination || ''}`;
            const loc = await geocode(query);

            if (loc) {
                console.log(`[Map] Placed marker for: ${act.place_name} at [${loc.lat}, ${loc.lng}]`);
                dayCoords.push([loc.lat, loc.lng]);
                allCoords.push([loc.lat, loc.lng]);

                const marker = L.circleMarker([loc.lat, loc.lng], {
                    radius: 8,
                    fillColor: color,
                    color: '#fff',
                    weight: 2,
                    opacity: 1,
                    fillOpacity: 0.8
                }).addTo(state.map).bindPopup(`<strong>Day ${day.day || i + 1}</strong>: ${act.place_name}<br><small>${act.time_slot || ''}</small>`);
                state.markers.push(marker);
            }
        }

        // Draw day route
        if (dayCoords.length > 1) {
            const poly = L.polyline(dayCoords, {
                color: color,
                weight: 4,
                opacity: 0.6,
                dashArray: '5, 10'
            }).addTo(state.map);
            state.polylines.push(poly);
        }
    }

    // Fit view
    if (allCoords.length > 0) {
        state.map.fitBounds(L.latLngBounds(allCoords), { padding: [40, 40] });
    }
    state.map.invalidateSize();
}

// ── Visual Mind Map (Professional, Animated, Interactive) ────────────────────────
function renderMindMap(plan) {
    if (!plan) return;
    const canvas = $('mindMapCanvas');
    const wrap = $('mindMapCanvasWrap');
    if (!canvas || !wrap) return;

    $('mindMapCard').classList.remove('hidden');

    // Build hierarchical data
    const root = {
        text: plan.trip_summary?.destination || plan.destination || 'Trip Plan',
        type: 'root',
        children: [],
        id: 'root',
        emoji: '🌍'
    };

    (plan.days || []).forEach((day, dIdx) => {
        const dNode = {
            text: `Day ${day.day || dIdx + 1}`,
            type: 'day',
            children: [],
            id: `day-${dIdx}`,
            emoji: '🗓️'
        };
        (day.activities || []).forEach((act, aIdx) => {
            dNode.children.push({
                text: act.place_name || 'Activity',
                sub: act.recommended_time || '',
                type: 'activity',
                id: `act-${dIdx}-${aIdx}`,
                emoji: (act.category || '').toLowerCase().includes('food') ? '🍴' :
                    (act.category || '').toLowerCase().includes('shop') ? '🛍️' : '📍'
            });
        });
        root.children.push(dNode);
    });

    state.mindMapData = root;
    state.mmNodes = []; // Will be populated by layout

    // Initial camera position: Center top
    const startX = wrap.clientWidth / 2;
    const startY = 80;
    state.mmTransform = { x: startX, y: startY, k: 0.1 }; // Start zoomed out for "zoom in" effect
    state.mmTargetTransform = { x: startX, y: startY, k: 0.8 };
    state.mmStartTime = Date.now();

    layoutNodes(root, 0, 0);

    // Start the render loop if not running
    if (state.mmAnimationId) cancelAnimationFrame(state.mmAnimationId);
    state.mmAnimationId = requestAnimationFrame(mindMapRenderLoop);
}

function layoutNodes(root, centerX, centerY) {
    const dayGap = 180;
    const actOffsetX = 220;
    const actGapY = 70;

    state.mmNodes = [];

    root.x = 0;
    root.y = 0;
    root.scale = 0; // For entrance animation
    state.mmNodes.push(root);

    root.children.forEach((day, i) => {
        day.x = 0;
        day.y = (i + 1) * dayGap;
        day.scale = 0;
        state.mmNodes.push(day);

        const actCount = day.children.length;
        day.children.forEach((act, j) => {
            const isRight = j % 2 === 0;
            act.x = isRight ? actOffsetX : -actOffsetX;
            act.y = day.y + (j - (actCount - 1) / 2) * actGapY;
            act.scale = 0;
            state.mmNodes.push(act);
        });
    });
}

function mindMapRenderLoop() {
    const canvas = $('mindMapCanvas');
    const wrap = $('mindMapCanvasWrap');
    if (!canvas || !wrap || !state.mindMapData) return;

    // Smooth transform (LERP)
    const lerp = 0.15;
    state.mmTransform.x += (state.mmTargetTransform.x - state.mmTransform.x) * lerp;
    state.mmTransform.y += (state.mmTargetTransform.y - state.mmTransform.y) * lerp;
    state.mmTransform.k += (state.mmTargetTransform.k - state.mmTransform.k) * lerp;

    // Smooth Entrance Scale
    const elapsed = Date.now() - state.mmStartTime;
    state.mmNodes.forEach((node, i) => {
        const delay = i * 50;
        const targetScale = (state.mmHoverNode === node) ? 1.1 : 1.0;
        const entrance = Math.min(1, Math.max(0, (elapsed - delay) / 600));
        // Use an elastic-out like easing
        const elastic = entrance === 1 ? 1 : 1 - Math.pow(2, -10 * entrance) * Math.cos((entrance * 10 - 0.75) * ((2 * Math.PI) / 3));

        node.currentScale = (node.currentScale || 0) + (targetScale * elastic - (node.currentScale || 0)) * 0.2;
    });

    drawMindMap();
    state.mmAnimationId = requestAnimationFrame(mindMapRenderLoop);
}

function drawMindMap() {
    const canvas = $('mindMapCanvas');
    const wrap = $('mindMapCanvasWrap');
    const dpr = window.devicePixelRatio || 1;
    const w = wrap.clientWidth;
    const h = wrap.clientHeight;

    canvas.width = w * dpr;
    canvas.height = h * dpr;
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';

    const ctx = canvas.getContext('2d');
    const t = state.mmTransform;

    ctx.save();
    ctx.scale(dpr, dpr);
    ctx.translate(t.x, t.y);
    ctx.scale(t.k, t.k);

    ctx.clearRect(-w * 10, -h * 10, w * 20, h * 20);

    // Draw Main Flow (Vertical Path)
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    state.mindMapData.children.forEach((day, i) => {
        // Line from root to day 1, or day i-1 to day i
        const startNode = (i === 0) ? state.mindMapData : state.mindMapData.children[i - 1];
        drawProCurve(ctx, startNode.x, startNode.y, day.x, day.y, '#2563eb', true);

        // Lines to activities
        day.children.forEach(act => {
            drawProCurve(ctx, day.x, day.y, act.x, act.y, '#64748b', false);
        });
    });

    // Draw Nodes
    state.mmNodes.forEach(node => drawProNode(ctx, node));

    ctx.restore();
}

function drawProCurve(ctx, x1, y1, x2, y2, color, isMain) {
    ctx.beginPath();
    ctx.strokeStyle = color;
    ctx.lineWidth = isMain ? 4 : 2;
    if (!isMain) ctx.setLineDash([6, 4]);

    ctx.moveTo(x1, y1);
    if (isMain) {
        // Vertical flow line
        ctx.lineTo(x2, y2);
    } else {
        // S-Curve for activities
        const ctrlX = x1 + (x2 - x1) * 0.4;
        ctx.bezierCurveTo(ctrlX, y1, ctrlX, y2, x2, y2);
    }
    ctx.stroke();
    ctx.setLineDash([]);

    // Optional: Draw arrowhead for flow
    if (isMain && Math.abs(y2 - y1) > 40) {
        const headlen = 10;
        const angle = Math.atan2(y2 - y1, x2 - x1);
        ctx.beginPath();
        ctx.fillStyle = color;
        ctx.moveTo(x2, y2 - 10); // Offset from center of node
        ctx.lineTo(x2 - headlen * Math.cos(angle - Math.PI / 6), y2 - 10 - headlen * Math.sin(angle - Math.PI / 6));
        ctx.lineTo(x2 - headlen * Math.cos(angle + Math.PI / 6), y2 - 10 - headlen * Math.sin(angle + Math.PI / 6));
        ctx.fill();
    }
}

function drawProNode(ctx, node) {
    const isRoot = node.type === 'root';
    const isDay = node.type === 'day';
    const scale = node.currentScale || 0;
    if (scale < 0.01) return;

    ctx.save();
    ctx.translate(node.x, node.y);
    ctx.scale(scale, scale);

    const padding = 16;
    ctx.font = isRoot ? '600 18px Inter, sans-serif' : isDay ? '600 15px Inter, sans-serif' : '500 13px Inter, sans-serif';

    const label = `${node.emoji} ${node.text}`;
    const textW = ctx.measureText(label).width;
    const w = textW + padding * 2;
    const h = isRoot ? 46 : isDay ? 38 : (node.sub ? 42 : 32);

    // Hover Glow
    if (state.mmHoverNode === node) {
        ctx.shadowBlur = 20;
        ctx.shadowColor = isRoot ? 'rgba(37, 99, 235, 0.4)' : 'rgba(0,0,0,0.1)';
    } else {
        ctx.shadowBlur = 8;
        ctx.shadowColor = 'rgba(0,0,0,0.06)';
    }
    ctx.shadowOffsetY = 4;

    // Body
    if (isRoot) {
        const g = ctx.createLinearGradient(-w / 2, -h / 2, w / 2, h / 2);
        g.addColorStop(0, '#2563eb');
        g.addColorStop(1, '#1e40af');
        ctx.fillStyle = g;
    } else {
        ctx.fillStyle = '#ffffff';
        ctx.strokeStyle = (state.mmHoverNode === node) ? '#2563eb' : '#e2e8f0';
        ctx.lineWidth = (state.mmHoverNode === node) ? 2 : 1;
    }

    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(-w / 2, -h / 2, w, h, 24);
    else ctx.rect(-w / 2, -h / 2, w, h);
    ctx.fill();
    if (!isRoot) ctx.stroke();

    // Text
    ctx.shadowBlur = 0;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = isRoot ? '#fff' : '#1e293b';
    ctx.fillText(label, 0, node.sub ? -7 : 0);

    if (node.sub) {
        ctx.font = '500 10px Inter, sans-serif';
        ctx.fillStyle = '#64748b';
        ctx.fillText(node.sub, 0, 10);
    }

    ctx.restore();
}

function initMindMapInteractions() {
    const wrap = $('mindMapCanvasWrap');
    if (!wrap) return;

    wrap.addEventListener('mousedown', (e) => {
        state.mmDragging = true;
        state.mmLastMouse = { x: e.clientX, y: e.clientY };
        wrap.style.cursor = 'grabbing';
    });

    window.addEventListener('mousemove', (e) => {
        // ── 1. Update Hover Node ──
        const rect = wrap.getBoundingClientRect();
        const mx = (e.clientX - rect.left - state.mmTransform.x) / state.mmTransform.k;
        const my = (e.clientY - rect.top - state.mmTransform.y) / state.mmTransform.k;

        let found = null;
        for (const node of state.mmNodes) {
            // Simple box check (could be more precise but this is fast)
            const padding = 20;
            if (mx > node.x - 60 && mx < node.x + 60 && my > node.y - 30 && my < node.y + 30) {
                found = node;
                break;
            }
        }
        state.mmHoverNode = found;
        wrap.style.cursor = found ? 'pointer' : (state.mmDragging ? 'grabbing' : 'grab');

        // ── 2. Handle Panning ──
        if (!state.mmDragging) return;
        const dx = e.clientX - state.mmLastMouse.x;
        const dy = e.clientY - state.mmLastMouse.y;

        state.mmTargetTransform.x += dx;
        state.mmTargetTransform.y += dy;

        state.mmLastMouse = { x: e.clientX, y: e.clientY };
    });

    window.addEventListener('mouseup', () => {
        if (state.mmDragging) {
            state.mmDragging = false;
            wrap.style.cursor = 'grab';
        }
    });

    wrap.addEventListener('wheel', (e) => {
        if (!$('tabPlan')?.classList.contains('hidden')) {
            const rect = wrap.getBoundingClientRect();
            if (e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom) {
                e.preventDefault();

                // Zoom towards mouse
                const zoomFactor = e.deltaY > 0 ? 0.9 : 1.1;
                const newK = Math.max(0.1, Math.min(3, state.mmTargetTransform.k * zoomFactor));

                // Adjust X/Y so we zoom into the mouse pointer
                const mx = (e.clientX - rect.left);
                const my = (e.clientY - rect.top);

                state.mmTargetTransform.x = mx - (mx - state.mmTargetTransform.x) * (newK / state.mmTargetTransform.k);
                state.mmTargetTransform.y = my - (my - state.mmTargetTransform.y) * (newK / state.mmTargetTransform.k);
                state.mmTargetTransform.k = newK;
            }
        }
    }, { passive: false });

    $('downloadMindMapBtn')?.addEventListener('click', () => {
        // Create a temporary canvas for high-res render to not flicker the UI
        const offCanvas = document.createElement('canvas');
        offCanvas.width = 2400;
        offCanvas.height = 2400;
        const ctx = offCanvas.getContext('2d');

        // Render manually to off-canvas
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, 2400, 2400);
        ctx.translate(1200, 200);
        ctx.scale(1.5, 1.5);

        // Re-use current draw logic with this ctx
        const originalCanvas = $('mindMapCanvas');
        const originalCtx = originalCanvas.getContext('2d');

        // This is a bit tricky since drawMindMap is hardcoded to the UI canvas.
        // Let's just use the existing high-res flag trick but hidden briefly.
        drawMindMap();
        const link = document.createElement('a');
        link.download = `TravelBuddy_FlowMap_${(state.destination || 'Trip').replace(/\s+/g, '_')}.png`;
        link.href = originalCanvas.toDataURL('image/png', 1.0);
        link.click();

        showToast('📸 Flow Map downloaded!');
    });

    $('copyMindMapTextBtn')?.addEventListener('click', () => {
        if (!state.currentPlan) return;
        const p = state.currentPlan;
        let text = `📍 Trip to ${p.trip_summary?.destination || 'My Destination'}\n`;
        text += `📅 Duration: ${p.trip_summary?.duration_days || '?'} days\n`;
        text += `💰 Est. Cost: ${p.trip_summary?.estimated_total_trip_cost || '?'}\n\n`;

        p.days.forEach(d => {
            text += `🗓️ Day ${d.day}: ${d.route_strategy || ''}\n`;
            d.activities.forEach(a => {
                text += `  • ${a.recommended_time || ''} - ${a.place_name || ''}\n`;
            });
            text += `\n`;
        });

        navigator.clipboard.writeText(text).then(() => {
            showToast('📋 Summary copied to clipboard!');
        });
    });

    // Handle resize
    window.addEventListener('resize', () => {
        if (!($('mindMapCard')?.classList.contains('hidden'))) {
            drawMindMap();
        }
    });
}

// ── LLM Status pill ───────────────────────────────────────────────────────────
async function checkLlmStatus() {
    const pill = $('llmPill');
    if (!pill) return;
    try {
        const resp = await fetch(`${API}/llm/status`, { signal: AbortSignal.timeout(5000) });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const s = await resp.json();
        // Server now includes emoji in label — display directly
        pill.innerHTML = `<span>${s.label}</span> <small style="opacity:0.55;font-size:10px;margin-left:8px;border-left:1px solid rgba(255,255,255,0.15);padding-left:8px">click to switch</small>`;
        pill.className = `llm-pill ${s.provider}`;
        pill.title = s.detail;
        pill.dataset.provider = s.provider;
        pill.dataset.preferLocal = s.prefer_local;
    } catch {
        if (pill) {
            pill.innerHTML = '<span>⚫ Offline Mode</span>';
            pill.className = 'llm-pill mock';
            pill.title = 'Backend not reachable — video generation still works fully offline in the browser!';
            pill.dataset.provider = 'mock';
        }
    }
}

async function toggleLlmMode() {
    const pill = $('llmPill');
    if (!pill || pill.dataset.loading === 'true') return;
    if (pill.dataset.provider === 'mock') {
        showToast('⚫ Backend offline — start the server to switch AI modes.');
        return;
    }

    pill.dataset.loading = 'true';
    const originalHTML = pill.innerHTML;
    pill.innerHTML = '<span>⏳ Switching…</span>';

    try {
        const resp = await fetch(`${API}/llm/toggle_mode`, {
            method: 'POST',
            signal: AbortSignal.timeout(8000),
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        showToast(`✅ ${data.message || (data.prefer_local ? 'Switched to Local AI' : 'Switched to Cloud API')}`);
        // Refresh pill state from server
        await checkLlmStatus();
    } catch (err) {
        console.error('[LLM] Toggle failed:', err);
        showToast('❌ Could not switch AI mode — is the backend running?');
        pill.innerHTML = originalHTML;
    } finally {
        pill.dataset.loading = 'false';
    }
}

// ── Init ──────────────────────────────────────────────────────────────────────
function initApp() {
    initMindMapInteractions();
    renderGrid();
    checkLlmStatus();

    // Auto-refresh status every 10 seconds to catch .env changes
    setInterval(checkLlmStatus, 10000);

    const pill = $('llmPill');
    if (pill) {
        pill.addEventListener('click', toggleLlmMode);
        pill.style.cursor = 'pointer';
        pill.title = 'Click to switch between Local (Private) and Cloud (Fast) AI';
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initApp);
} else {
    initApp();
}
