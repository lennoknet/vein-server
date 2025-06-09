const logsContainer = document.getElementById("logs");
const autoScroll = document.getElementById("auto-scroll");
const filterErrors = document.getElementById("filter-errors");
const statusBox = document.getElementById("restart-status");
const dialog = document.getElementById("confirm-dialog");
const confirmMessage = document.getElementById("confirm-message");
const confirmYes = document.getElementById("confirm-yes");
const serviceStatus = document.getElementById("service-status");
const serviceUptime = document.getElementById("service-uptime");
const serviceStarted = document.getElementById("service-started");

let logs = [];
let allLogElements = [];

function updateStatus(type, msg) {
  statusBox.className = `status ${type}`;
  statusBox.textContent = msg;
}

function highlightLog(line) {
  const div = document.createElement("div");
  div.textContent = line;

  const lower = line.toLowerCase();
  if (lower.includes("error")) {
    div.classList.add("log-line", "error");
    div.dataset.logType = "error";
  } else if (lower.includes("warning") || lower.includes("warn")) {
    div.classList.add("log-line", "warning");
    div.dataset.logType = "warning";
  } else if (lower.includes("info")) {
    div.classList.add("log-line", "info");
    div.dataset.logType = "info";
  } else {
    div.dataset.logType = "normal";
  }

  return div;
}

function filterLogs() {
  const showErrorsOnly = filterErrors.checked;
  
  allLogElements.forEach(element => {
    if (showErrorsOnly) {
      element.style.display = element.dataset.logType === "error" ? "block" : "none";
    } else {
      element.style.display = "block";
    }
  });

  if (autoScroll.checked) {
    logsContainer.scrollTop = logsContainer.scrollHeight;
  }
}

function fetchLogs() {
  fetch("/get-logs")
    .then(res => res.json())
    .then(data => {
      if (data.logs.length !== logs.length) {
        const newLogs = data.logs.slice(logs.length);
        logs = data.logs;
        
        // Add new logs to display
        newLogs.forEach(log => {
          const line = highlightLog(log);
          logsContainer.appendChild(line);
          allLogElements.push(line);
        });
        
        // Apply current filter
        filterLogs();
      }
    })
    .catch(err => console.error("Error fetching logs:", err));
}

function fetchServiceInfo() {
  fetch("/get-service-info")
    .then(res => res.json())
    .then(data => {
      // Update service status
      serviceStatus.textContent = data.status === "running" ? "Running" : 
                                data.status === "stopped" ? "Stopped" : "Unknown";
      serviceStatus.className = `service-status ${data.status}`;
      
      // Update uptime and start time
      serviceUptime.textContent = data.uptime;
      serviceStarted.textContent = data.started_at;
    })
    .catch(err => console.error("Error fetching service info:", err));
}

function performAction(endpoint, type) {
  fetch(endpoint, { method: "POST" })
    .then(() => pollStatus())
    .catch(() => updateStatus("error", `Failed to ${type}`));
}

function pollStatus() {
  fetch("/get-action-status")
    .then(res => res.json())
    .then(data => {
      updateStatus(data.status, data.message);
      if (data.status === "running") {
        setTimeout(pollStatus, 1000);
      }
    });
}

function confirmAndRun(type, endpoint) {
  confirmMessage.textContent = `⚠️ Are you sure you want to ${type} the server? ⚠️`;
  dialog.showModal();
  confirmYes.onclick = () => {
    dialog.close();
    performAction(endpoint, type);
  };
}

// Event Listeners
document.getElementById("clear-logs").onclick = () => {
  fetch("/clear-logs", { method: "POST" })
    .then(() => {
      logsContainer.innerHTML = "";
      logs = [];
      allLogElements = [];
    })
    .catch(() => alert("Failed to clear logs."));
};

// Add event listener for error filter
filterErrors.addEventListener("change", filterLogs);

document.getElementById("restart-service").onclick = () => confirmAndRun("restart", "/restart-service");
document.getElementById("stop-service").onclick = () => confirmAndRun("stop", "/stop-service");
document.getElementById("start-service").onclick = () => confirmAndRun("start", "/start-service");

// Update logs every second
setInterval(fetchLogs, 1000);
// Update service info every 5 seconds
setInterval(fetchServiceInfo, 5000);

// Initial fetch
fetchLogs();
fetchServiceInfo();