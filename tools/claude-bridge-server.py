#!/usr/bin/env python3
"""
Claude Bridge Server - Python Version
Simpler HTTP server for Claude Code <-> Browser Claude communication
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import datetime
from urllib.parse import urlparse, parse_qs

messages = []
message_id = 0

class BridgeHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status=200, content_type='application/json'):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def _send_json(self, data, status=200):
        self._set_headers(status)
        self.wfile.write(json.dumps(data).encode())

    def do_OPTIONS(self):
        self._set_headers(204)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == '/health':
            self._send_json({
                'status': 'healthy',
                'messageCount': len(messages),
                'unreadCount': len([m for m in messages if m['status'] == 'unread'])
            })

        elif path == '/messages':
            filtered = messages
            if 'from' in query:
                filtered = [m for m in filtered if m['from'] == query['from'][0]]
            if 'to' in query:
                filtered = [m for m in filtered if m['to'] == query['to'][0]]

            self._send_json({
                'messages': filtered,
                'total': len(filtered)
            })

        elif path == '/messages/unread':
            to_filter = query.get('to', [None])[0]
            unread = [m for m in messages if m['status'] == 'unread']
            if to_filter:
                unread = [m for m in unread if m['to'] == to_filter]

            self._send_json({
                'messages': unread,
                'count': len(unread)
            })

        elif path.startswith('/messages/'):
            msg_id = int(path.split('/')[-1])
            msg = next((m for m in messages if m['id'] == msg_id), None)
            if msg:
                self._send_json(msg)
            else:
                self._send_json({'error': 'Message not found'}, 404)

        else:
            self._send_json({'error': 'Not found'}, 404)

    def do_POST(self):
        global message_id
        content_length = int(self.headers['Content-Length'])
        body = json.loads(self.rfile.read(content_length).decode())

        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/messages':
            if not all(k in body for k in ['from', 'to', 'content']):
                self._send_json({'error': 'Missing required fields'}, 400)
                return

            message_id += 1
            message = {
                'id': message_id,
                'from': body['from'],
                'to': body['to'],
                'content': body['content'],
                'type': body.get('type', 'text'),
                'status': 'unread',
                'timestamp': datetime.datetime.utcnow().isoformat() + 'Z'
            }
            messages.append(message)

            print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] New message #{message['id']}: {body['from']} -> {body['to']}")

            self._send_json({
                'success': True,
                'message': message
            }, 201)

        elif path.endswith('/read'):
            msg_id = int(path.split('/')[-2])
            msg = next((m for m in messages if m['id'] == msg_id), None)
            if msg:
                msg['status'] = 'read'
                msg['readAt'] = datetime.datetime.utcnow().isoformat() + 'Z'
                self._send_json({'success': True, 'message': msg})
            else:
                self._send_json({'error': 'Message not found'}, 404)

        else:
            self._send_json({'error': 'Not found'}, 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith('/messages/'):
            msg_id = int(path.split('/')[-1])
            global messages
            messages = [m for m in messages if m['id'] != msg_id]
            self._send_json({'success': True, 'message': 'Message deleted'})
        else:
            self._send_json({'error': 'Not found'}, 404)

    def log_message(self, format, *args):
        # Suppress default logging
        pass

def run(port=9999):
    server = HTTPServer(('localhost', port), BridgeHandler)
    print(f'[BRIDGE] Claude Bridge Server started on http://localhost:{port}')
    print()
    print('Endpoints:')
    print('  POST   /messages          - Send a message')
    print('  GET    /messages          - Get all messages')
    print('  GET    /messages/unread   - Get unread messages')
    print('  GET    /messages/:id      - Get specific message')
    print('  POST   /messages/:id/read - Mark message as read')
    print('  DELETE /messages/:id      - Delete message')
    print('  GET    /health            - Health check')
    print()
    print('Press CTRL+C to stop')
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n[BRIDGE] Server stopped')
        server.shutdown()

if __name__ == '__main__':
    run()
