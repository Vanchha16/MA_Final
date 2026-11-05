from app import create_app
from app.realtime import socketio

app = create_app()

if __name__ == "__main__":
    # host 0.0.0.0 so the phone/emulator can reach the API over the network.
    # socketio.run serves the REST API and the real-time socket (app/realtime.py) on one port.
    socketio.run(app, host="0.0.0.0", port=5000, debug=True, allow_unsafe_werkzeug=True)
