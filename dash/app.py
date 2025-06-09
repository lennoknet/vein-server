from flask import Flask, render_template, jsonify, request, Response
import subprocess
import threading
import time
import os
import json
from datetime import datetime, timedelta
from collections import deque
import signal

app = Flask(__name__)

# Global variables to store data
# Rolling logs for display (max 800 lines)
display_logs = deque(maxlen=800)
# Full logs for download (unlimited)
full_logs = deque()
service_status = {"status": "unknown", "message": ""}
action_status = {"action": "none", "status": "none", "message": ""}
service_info = {"uptime": "Unknown", "started_at": "Unknown", "status": "unknown"}

# Log watching variables
log_process = None
log_thread = None
log_restart_count = 0

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/restart-service', methods=['POST'])
def restart_service():
    global action_status
    action_status = {"action": "restart", "status": "running", "message": "Restarting vein-server service..."}
    
    # Start a thread to run the restart command
    def run_restart():
        global action_status
        try:
            process = subprocess.run(
                ["systemctl", "restart", "vein-server.service"], 
                check=True, 
                capture_output=True,
                text=True
            )
            action_status = {"action": "restart", "status": "success", "message": "Service restarted successfully"}
            # Update service status after restart
            check_service_status()
        except subprocess.CalledProcessError as e:
            action_status = {
                "action": "restart", 
                "status": "error", 
                "message": f"Error restarting service: {e.stderr}"
            }
    
    thread = threading.Thread(target=run_restart)
    thread.daemon = True
    thread.start()
    
    return jsonify({"message": "Restart initiated"})

@app.route('/start-service', methods=['POST'])
def start_service():
    global action_status
    action_status = {"action": "start", "status": "running", "message": "Starting vein-server service..."}
    
    def run_start():
        global action_status
        try:
            process = subprocess.run(
                ["systemctl", "start", "vein-server.service"], 
                check=True, 
                capture_output=True,
                text=True
            )
            action_status = {"action": "start", "status": "success", "message": "Service started successfully"}
            # Update service status after start
            check_service_status()
        except subprocess.CalledProcessError as e:
            action_status = {
                "action": "start", 
                "status": "error", 
                "message": f"Error starting service: {e.stderr}"
            }
    
    thread = threading.Thread(target=run_start)
    thread.daemon = True
    thread.start()
    
    return jsonify({"message": "Start initiated"})

@app.route('/stop-service', methods=['POST'])
def stop_service():
    global action_status
    action_status = {"action": "stop", "status": "running", "message": "Stopping vein-server service..."}
    
    def run_stop():
        global action_status
        try:
            process = subprocess.run(
                ["systemctl", "stop", "vein-server.service"], 
                check=True, 
                capture_output=True,
                text=True
            )
            action_status = {"action": "stop", "status": "success", "message": "Service stopped successfully"}
            # Update service status after stop
            check_service_status()
        except subprocess.CalledProcessError as e:
            action_status = {
                "action": "stop", 
                "status": "error", 
                "message": f"Error stopping service: {e.stderr}"
            }
    
    thread = threading.Thread(target=run_stop)
    thread.daemon = True
    thread.start()
    
    return jsonify({"message": "Stop initiated"})

@app.route('/get-logs', methods=['GET'])
def get_logs():
    return jsonify({"logs": list(display_logs)})

@app.route('/get-action-status', methods=['GET'])
def get_action_status():
    return jsonify(action_status)

@app.route('/get-service-status', methods=['GET'])
def get_service_status_route():
    check_service_status()
    return jsonify(service_status)

@app.route('/get-service-info', methods=['GET'])
def get_service_info():
    update_service_info()
    return jsonify(service_info)

@app.route('/download-logs', methods=['GET'])
def download_logs():
    # Format current date for filename
    now = datetime.now()
    date_str = now.strftime("%Y%m%d_%H%M%S")
    filename = f"vein_server_logs_{date_str}.txt"
    
    # Create log content from full logs
    log_content = "\n".join(full_logs)
    
    # Create response with log content as downloadable file
    response = Response(log_content)
    response.headers["Content-Disposition"] = f"attachment; filename={filename}"
    response.headers["Content-Type"] = "text/plain"
    
    return response

def update_service_info():
    """Update service information including uptime and start time"""
    global service_info
    try:
        # Get service status
        status_result = subprocess.run(
            ["systemctl", "is-active", "vein-server.service"],
            capture_output=True,
            text=True
        )
        
        if status_result.stdout.strip() == "active":
            # Get detailed service information
            show_result = subprocess.run(
                ["systemctl", "show", "vein-server.service", "--property=ActiveEnterTimestamp,SubState"],
                capture_output=True,
                text=True
            )
            
            # Parse the output
            properties = {}
            for line in show_result.stdout.strip().split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    properties[key] = value
            
            # Get start time
            if 'ActiveEnterTimestamp' in properties and properties['ActiveEnterTimestamp']:
                try:
                    # Parse systemd timestamp format
                    start_time_str = properties['ActiveEnterTimestamp']
                    # Remove timezone info for simpler parsing
                    if ' ' in start_time_str:
                        start_time_str = ' '.join(start_time_str.split()[:-1])
                    
                    start_time = datetime.strptime(start_time_str, "%a %Y-%m-%d %H:%M:%S")
                    
                    # Calculate uptime
                    uptime_delta = datetime.now() - start_time
                    
                    # Format uptime
                    days = uptime_delta.days
                    hours, remainder = divmod(uptime_delta.seconds, 3600)
                    minutes, seconds = divmod(remainder, 60)
                    
                    if days > 0:
                        uptime_str = f"{days}d {hours}h {minutes}m {seconds}s"
                    elif hours > 0:
                        uptime_str = f"{hours}h {minutes}m {seconds}s"
                    elif minutes > 0:
                        uptime_str = f"{minutes}m {seconds}s"
                    else:
                        uptime_str = f"{seconds}s"
                    
                    service_info = {
                        "uptime": uptime_str,
                        "started_at": start_time.strftime("%Y-%m-%d %H:%M:%S"),
                        "status": "running"
                    }
                except (ValueError, IndexError) as e:
                    service_info = {
                        "uptime": "Error parsing time",
                        "started_at": "Unknown",
                        "status": "running"
                    }
            else:
                service_info = {
                    "uptime": "Unknown",
                    "started_at": "Unknown",
                    "status": "running"
                }
        else:
            service_info = {
                "uptime": "Not running",
                "started_at": "Not running",
                "status": "stopped"
            }
            
    except Exception as e:
        service_info = {
            "uptime": f"Error: {str(e)}",
            "started_at": "Error",
            "status": "unknown"
        }

def check_service_status():
    """Check the current status of the vein-server service"""
    global service_status
    try:
        # Run systemctl is-active to check if the service is running
        is_active = subprocess.run(
            ["systemctl", "is-active", "vein-server.service"],
            capture_output=True,
            text=True
        )
        
        # Get more detailed status information
        status_output = subprocess.run(
            ["systemctl", "status", "vein-server.service"],
            capture_output=True,
            text=True
        )
        
        if is_active.stdout.strip() == "active":
            service_status = {
                "status": "running",
                "message": "Service is running",
                "details": status_output.stdout
            }
        else:
            service_status = {
                "status": "stopped",
                "message": "Service is not running",
                "details": status_output.stdout
            }
    except Exception as e:
        service_status = {
            "status": "unknown",
            "message": f"Error checking service status: {str(e)}"
        }

def restart_log_watcher():
    """Restart the log watching process"""
    global log_process, log_restart_count
    
    # Kill existing process if it exists
    if log_process:
        try:
            log_process.terminate()
            log_process.wait(timeout=5)
        except:
            try:
                log_process.kill()
                log_process.wait(timeout=2)
            except:
                pass
    
    log_restart_count += 1
    error_msg = f"Log watcher restarted ({log_restart_count})"
    display_logs.append(error_msg)
    full_logs.append(error_msg)
    
    # Start new process
    try:
        log_process = subprocess.Popen(
            ["journalctl", "-u", "vein-server.service", "-f", "-n", "0", "--no-pager"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
    except Exception as e:
        error_msg = f"Failed to restart log watcher: {str(e)}"
        display_logs.append(error_msg)
        full_logs.append(error_msg)

def watch_logs():
    global display_logs, full_logs, log_process
    
    while True:
        try:
            if not log_process or log_process.poll() is not None:
                restart_log_watcher()
            
            if log_process:
                # Set a timeout for reading
                line = log_process.stdout.readline()
                if line:
                    line = line.strip()
                    if line:
                        # Add to both display logs (rolling) and full logs (complete)
                        display_logs.append(line)
                        full_logs.append(line)
                else:
                    # No line received, check if process is still alive
                    if log_process.poll() is not None:
                        # Process died, restart it
                        restart_log_watcher()
                    time.sleep(0.1)
            else:
                time.sleep(1)
                
        except Exception as e:
            error_msg = f"Error in log watcher: {str(e)}"
            display_logs.append(error_msg)
            full_logs.append(error_msg)
            time.sleep(5)  # Wait before trying again

def initialize_logs():
    """Initialize logs with recent entries"""
    global display_logs, full_logs
    try:
        # Get the last 800 lines for display
        result = subprocess.run(
            ["journalctl", "-u", "vein-server.service", "-n", "800", "--no-pager"],
            capture_output=True,
            text=True
        )
        
        if result.stdout:
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if line.strip():
                    display_logs.append(line.strip())
                    full_logs.append(line.strip())
    except Exception as e:
        error_msg = f"Error initializing logs: {str(e)}"
        display_logs.append(error_msg)
        full_logs.append(error_msg)

@app.route('/clear-logs', methods=['POST'])
def clear_logs():
    global display_logs, full_logs
    display_logs.clear()
    full_logs.clear()
    return jsonify({"message": "Logs cleared"})

@app.route('/restart-log-watcher', methods=['POST'])
def restart_log_watcher_endpoint():
    """Manual endpoint to restart log watcher"""
    restart_log_watcher()
    return jsonify({"message": "Log watcher restarted"})

# Cleanup function
def cleanup():
    global log_process
    if log_process:
        try:
            log_process.terminate()
            log_process.wait(timeout=5)
        except:
            try:
                log_process.kill()
            except:
                pass

if __name__ == '__main__':
    # Setup signal handlers for clean shutdown
    import atexit
    atexit.register(cleanup)
    
    # Check initial service status
    check_service_status()
    update_service_info()
    
    # Initialize logs with recent entries
    initialize_logs()
    
    # Start log watching thread
    log_thread = threading.Thread(target=watch_logs)
    log_thread.daemon = True
    log_thread.start()
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5000, debug=True)