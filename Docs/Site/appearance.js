(() => {
  const controls = document.getElementById("appearance-controls");
  const preview = document.getElementById("appearance-preview");
  const stage = document.querySelector(".capture-stage");
  const container = document.getElementById("appearance-player");
  const playButton = document.getElementById("play-appearance");
  const previewButton = document.getElementById("show-appearance-preview");
  const download = document.getElementById("appearance-download");
  const status = document.getElementById("playback-status");
  const missing = document.getElementById("preview-missing");
  const treatments = {
    chio: { title: "Chio", description: "Chio: the default palette and familiar group framing, with its recipe spacing." },
    opencode: { title: "OpenCode-inspired", description: "OpenCode-inspired: warm accents, restrained surfaces and accent edges, with roomier recipe spacing." },
    btop: { title: "btop-inspired", description: "btop-inspired: brighter instrument colors and titles set into compact group outlines, with its recipe spacing." },
  };
  const allocations = { wide: { cols: 100, rows: 30 }, narrow: { cols: 36, rows: 64 } };
  let selectedTreatment = "chio";
  let selectedWidth = "wide";
  let player = null;

  function stopPlayback() {
    if (player) {
      player.pause();
      player.dispose();
      player = null;
    }
    container.replaceChildren();
    container.hidden = true;
    preview.hidden = !missing.hidden;
    previewButton.hidden = true;
    playButton.hidden = typeof window.AsciinemaPlayer === "undefined";
    document.getElementById("capture-kind").textContent = "Static terminal preview";
  }

  function showPreview() {
    stopPlayback();
    status.hidden = true;
  }

  function updateSelection() {
    showPreview();
    selectedTreatment = controls.elements.treatment.value;
    selectedWidth = controls.elements.width.value;
    const treatment = treatments[selectedTreatment];
    const { cols, rows } = allocations[selectedWidth];
    const asset = `recordings/appearance/${selectedTreatment}-${selectedWidth}`;
    missing.hidden = true;
    preview.hidden = false;
    preview.src = `${asset}.png`;
    preview.alt = `${treatment.title} treatment of the same local list, editable form and instruments, in a ${cols}-column by ${rows}-row terminal.`;
    stage.dataset.width = selectedWidth;
    download.href = `${asset}.cast`;
    document.getElementById("capture-title").textContent = `${treatment.title} · ${cols} × ${rows}`;
    document.getElementById("capture-description").textContent = treatment.description;
    document.getElementById("appearance-command").textContent = `swift run -c release chio-dashboard --appearance --treatment ${selectedTreatment} --density recipe`;
    document.getElementById("allocation-note").textContent = `Use a ${cols} × ${rows} terminal for the matching ${selectedWidth} capture. Terminal size is chosen in your terminal, not by a command flag.`;
  }

  function playbackFailed() {
    const hadPlayerFocus = container.contains(document.activeElement);
    stopPlayback();
    status.textContent = "Playback unavailable. Download the recording or run the matching command locally.";
    status.hidden = false;
    if (hadPlayerFocus) playButton.focus({ preventScroll: true });
  }

  playButton.addEventListener("click", () => {
    status.hidden = true;
    try {
      const { cols, rows } = allocations[selectedWidth];
      container.hidden = false;
      preview.hidden = true;
      missing.hidden = true;
      previewButton.hidden = false;
      playButton.hidden = true;
      document.getElementById("capture-kind").textContent = "Recorded terminal session";
      const created = window.AsciinemaPlayer.create(download.getAttribute("href"), container, {
        cols, rows, fit: "width", controls: true, autoplay: true, cursorMode: "steady",
      });
      player = created;
      created.addEventListener("error", () => {
        if (player === created) playbackFailed();
      });
      created.el.focus({ preventScroll: true });
    } catch {
      playbackFailed();
      playButton.focus({ preventScroll: true });
    }
  });
  previewButton.addEventListener("click", () => {
    showPreview();
    playButton.focus({ preventScroll: true });
  });
  preview.addEventListener("error", () => {
    preview.hidden = true;
    missing.hidden = false;
  });
  preview.addEventListener("load", () => { missing.hidden = true; });
  controls.addEventListener("change", updateSelection);
  controls.addEventListener("submit", event => event.preventDefault());
  document.addEventListener("visibilitychange", () => { if (document.hidden) player?.pause(); });
  window.addEventListener("pagehide", stopPlayback);
  controls.hidden = false;
  playButton.hidden = typeof window.AsciinemaPlayer === "undefined";
})();
