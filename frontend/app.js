/* ══════════════════════════════════════════════════════════════════════════════
   TravelBuddy AI — app.js
   • 100 % offline capable (video generated client-side via video_generator.js)
   • Backend (http://127.0.0.1:8000) used for AI analysis + story — optional
   • Max 50 photos · 50 MB each · all browser-decodable image formats + RAW
   • Drag-and-drop zone + click-to-browse  (both fully wired)
   • Drag-to-REORDER thumbnails in the preview grid
   ══════════════════════════════════════════════════════════════════════════════ */
'use strict';

const API = ''; // Use relative path since backend serves frontend
const MAX_FILES = 50;
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
    renderGrid();
}

$('clearBtn')?.addEventListener('click', () => { state.photos = []; renderGrid(); showErr('uploadErr', ''); });

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

    // Clamp to 50
    sources = sources.slice(0, 50);

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

    try {
        // ── 4-priority photo path resolution (robust, localStorage-cached) ────
        // P0: localStorage cache  — survives page reload, set after every success
        // P1: state.analysed      — from prior Analyse click this session
        // P2: auto-upload browser files — only if photos dropped in step 1
        // P3: GET /images/list    — photos already on server (with retry)
        // Shows real error reason if all fail.

        const LS_KEY = 'tb_server_paths';

        // P0: try localStorage cache first
        if (serverPaths.length === 0) {
            try {
                const cached = JSON.parse(localStorage.getItem(LS_KEY) || '[]');
                if (Array.isArray(cached) && cached.length > 0) {
                    serverPaths = cached;
                    setProgress(4, `📂 Loaded ${serverPaths.length} photo paths from cache.`);
                }
            } catch (_) { }
        }

        // P2: auto-upload browser files if still no paths
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

        // P3: GET /images/list — retry up to 3 times with 1s gap
        if (serverPaths.length === 0) {
            setProgress(5, '🔎 Checking server for existing photos…');
            for (let attempt = 1; attempt <= 3; attempt++) {
                try {
                    const lr = await fetch(`${API}/images/list`, {
                        signal: AbortSignal.timeout(8_000),
                    });
                    if (lr.ok) {
                        const listData = await lr.json();
                        serverPaths = (listData.images || []).slice(0, 50);
                        if (serverPaths.length > 0) {
                            setProgress(8, `✅ Found ${serverPaths.length} photos on server.`);
                            break;
                        }
                    } else {
                        console.warn(`[Cinematic] /images/list attempt ${attempt} → HTTP ${lr.status}`);
                    }
                } catch (listErr) {
                    console.warn(`[Cinematic] /images/list attempt ${attempt} failed:`, listErr.message);
                    if (attempt < 3) await new Promise(r => setTimeout(r, 1000));
                }
            }
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
            duration_s: 30,   // default 30 s — fast render
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
                            vid.src = `${API}${s.video_url}`;
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

    // Trigger map after layout settles
    setTimeout(async () => {
        try { await renderMap(raw); }
        catch (e) { console.error("Map render failed:", e); }
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
