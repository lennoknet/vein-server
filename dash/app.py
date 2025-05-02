from flask import Flask, render_template, jsonify, request, Response
import subprocess
import threading
import time
import os
import json
from datetime import datetime

app = Flask(__name__)

# Global variables to store data
from collections import deque
logs = deque(maxlen=800)
service_status = {"status": "unknown", "message": ""}
action_status = {"action": "none", "status": "none", "message": ""}

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
    return jsonify({"logs": list(logs)})

@app.route('/get-action-status', methods=['GET'])
def get_action_status():
    return jsonify(action_status)

@app.route('/get-service-status', methods=['GET'])
def get_service_status_route():
    check_service_status()
    return jsonify(service_status)

@app.route('/download-logs', methods=['GET'])
def download_logs():
    # Format current date for filename
    now = datetime.now()
    date_str = now.strftime("%Y%m%d_%H%M%S")
    filename = f"vein_server_logs_{date_str}.txt"
    
    # Create log content
    log_content = "\n".join(logs)
    
    # Create response with log content as downloadable file
    response = Response(log_content)
    response.headers["Content-Disposition"] = f"attachment; filename={filename}"
    response.headers["Content-Type"] = "text/plain"
    
    return response

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

def watch_logs():
    global logs
    try:
        process = subprocess.Popen(
            ["journalctl", "-u", "vein-server.service", "-f", "-n", "100", "--no-pager"],
            stdout=subprocess.PIPE,
            text=True
        )
        
        while True:
            line = process.stdout.readline().strip()
            if line:
                logs.append(line)
            time.sleep(0.1)
    except Exception as e:
        logs.append(f"Error watching logs: {str(e)}")

@app.route('/clear-logs', methods=['POST'])
def clear_logs():
    global logs
    logs.clear()
    return jsonify({"message": "Logs cleared"})

if __name__ == '__main__':
    # Check initial service status
    check_service_status()
    
    # Start log watching thread
    log_thread = threading.Thread(target=watch_logs)
    log_thread.daemon = True
    log_thread.start()
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5000, debug=True)
