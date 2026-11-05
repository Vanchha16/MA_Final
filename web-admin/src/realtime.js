import { io } from 'socket.io-client';
import { tokenStore } from './api';

/**
 * The Socket.IO connection to Flask (backend app/realtime.py). Staff are in the "staff" room,
 * so the server pushes `order_updated` (an order was placed, paid, shipped, cancelled...) and
 * `admin_update` (a new contact message or review). The events are only signals: pages load
 * the new data with the normal REST calls.
 * Same origin as the page: Flask serves the built admin, and `npm run dev` proxies /socket.io.
 */
export function connectRealtime(onChange) {
  const socket = io({
    path: '/socket.io',
    auth: (cb) => cb({ token: tokenStore.get() }), // read again on every reconnect
  });
  socket.on('order_updated', onChange);
  socket.on('admin_update', onChange);
  // After a dropped connection comes back, catch up on anything missed meanwhile
  socket.io.on('reconnect', onChange);
  return () => socket.disconnect();
}
