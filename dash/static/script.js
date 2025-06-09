const logsContainer = document.getElementById("logs");
const autoScroll = document.getElementById("auto-scroll");
const filterErrors = document.getElementById("filter-errors");
const filterChat = document.getElementById("filter-chat");
const filterKilled = document.getElementById("filter-killed");
const filterClaimed = document.getElementById("filter-claimed");
const statusBox = document.getElementById("restart-status");
const dialog = document.getElementById("confirm-dialog");
const confirmMessage = document.getElementById("confirm-message");
const confirmYes = document.getElementById("confirm-yes");
const serviceStatus = document.getElementById("service-status");
const serviceUptime = document.getElementById("service-uptime");
const serviceStarted = document.getElementById("service-started");

let logs = [];
let allLogElements = [];
let lastLogCount = 0;
let logStallCount = 0;
let connectionStatus = "connected";

function updateStatus(type, msg) {
  statusBox.className = `status ${type}`;
  statusBox.textContent = msg;
}

function highlightLog(line) {
  const div = document.createElement("div");
  div.textContent = line;

  const lower = line.toLowerCase();
  
  // Check for different log types in priority order
  if (lower.includes("logveinchat")) {
    div.classList.add("log-line", "chat");
    div.dataset.logType = "chat";
  } else if (lower.includes("killed")) {
    div.classList.add("log-line", "killed");
    div.dataset.logType = "killed";
  } else if (lower.includes("claimed")) {
    div.classList.add("log-line", "claimed");
    div.dataset.logType = "claimed";
  } else if (lower.includes("error")) {
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
  const showChatOnly = filterChat.checked;
  const showKilledOnly = filterKilled.checked;
  const showClaimedOnly = filterClaimed.checked;
  
  // Check if any exclusive filters are active
  const exclusiveFilters = [showErrorsOnly, showChatOnly, showKilledOnly, showClaimedOnly];
  const anyExclusiveFilter = exclusiveFilters.some(filter => filter);
  
  allLogElements.forEach(element => {
    let shouldShow = true;
    
    if (anyExclusiveFilter) {
      // If any exclusive filter is active, only show matching types
      shouldShow = false;
      
      if (showErrorsOnly && element.dataset.logType === "error") {
        shouldShow = true;
      }
      if (showChatOnly && element.dataset.logType === "chat") {
        shouldShow = true;
      }
      if (showKilledOnly && element.dataset.logType === "killed") {
        shouldShow = true;
      }
      if (showClaimedOnly && element.dataset.logType === "claimed") {
        shouldShow = true;
      }
    }
    
    element.style.display = shouldShow ? "block" : "none";
  });

  if (autoScroll.checked) {
    logsContainer.scrollTop = logsContainer.scrollHeight;
  }
}

function checkLogStall() {
  // Check if logs have stopped updating
  if (logs.length === lastLogCount) {
    logStallCount++;
    if (logStallCount >= 30) { // 30 seconds without new logs
      if (connectionStatus === "connected") {
        connectionStatus = "stalled";
        updateStatus("warning", "Log connection may be stalled - trying to reconnect...");
        
        // Try to restart the log watcher
        fetch("/restart-log-watcher", { method: "POST" })
          .then(() => {
            logStallCount = 0;
            connectionStatus = "connected";
            updateStatus("success", "Log watcher restarted");
          })
          .catch(() => {
            updateStatus("error", "Failed to restart log watcher");
          });
      }
    }
  } else {
    logStallCount = 0;
    if (connectionStatus !== "connected") {
      connectionStatus = "connected";
      updateStatus("success", "Log connection restored");
    }
  }
  lastLogCount = logs.length;
}

function fetchLogs() {
  fetch("/get-logs")
    .then(res => {
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      return res.json();
    })
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
        
        // Reset connection issues
        if (connectionStatus !== "connected") {
          connectionStatus = "connected";
          updateStatus("success", "Connection restored");
        }
      }
    })
    .catch(err => {
      console.error("Error fetching logs:", err);
      if (connectionStatus === "connected") {
        connectionStatus = "error";
        updateStatus("error", "Connection error - retrying...");
      }
    });
}

function fetchServiceInfo() {
  fetch("/get-service-info")
    .then(res => {
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      return res.json();
    })
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
    .then(res => {
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      return res.json();
    })
    .then(() => pollStatus())
    .catch(err => {
      console.error(`Error ${type}ing service:`, err);
      updateStatus("error", `Failed to ${type}: ${err.message}`);
    });
}

function pollStatus() {
  fetch("/get-action-status")
    .then(res => {
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      return res.json();
    })
    .then(data => {
      updateStatus(data.status, data.message);
      if (data.status === "running") {
        setTimeout(pollStatus, 1000);
      }
    })
    .catch(err => {
      console.error("Error polling status:", err);
      updateStatus("error", "Connection error");
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
    .then(res => {
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      return res.json();
    })
    .then(() => {
      logsContainer.innerHTML = "";
      logs = [];
      allLogElements = [];
      updateStatus("success", "Logs cleared");
    })
    .catch(err => {
      console.error("Error clearing logs:", err);
      updateStatus("error", "Failed to clear logs");
    });
};

// Add manual log watcher restart button if it exists
const restartLogsBtn = document.getElementById("restart-logs");
if (restartLogsBtn) {
  restartLogsBtn.onclick = () => {
    fetch("/restart-log-watcher", { method: "POST" })
      .then(res => {
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}`);
        }
        return res.json();
      })
      .then(() => {
        logStallCount = 0;
        connectionStatus = "connected";
        updateStatus("success", "Log watcher restarted");
      })
      .catch(err => {
        console.error("Error restarting log watcher:", err);
        updateStatus("error", "Failed to restart log watcher");
      });
  };
}

// Add event listeners for all filters
filterErrors.addEventListener("change", filterLogs);
filterChat.addEventListener("change", filterLogs);
filterKilled.addEventListener("change", filterLogs);
filterClaimed.addEventListener("change", filterLogs);

document.getElementById("restart-service").onclick = () => confirmAndRun("restart", "/restart-service");
document.getElementById("stop-service").onclick = () => confirmAndRun("stop", "/stop-service");
document.getElementById("start-service").onclick = () => confirmAndRun("start", "/start-service");

// Update logs every second
setInterval(fetchLogs, 1000);

// Check for log stalls every second
setInterval(checkLogStall, 1000);

// Update service info every 5 seconds
setInterval(fetchServiceInfo, 5000);

// Initial fetch
fetchLogs();
fetchServiceInfo();