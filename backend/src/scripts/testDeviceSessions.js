/**
 * Manual integration checks for per-device sessions.
 * Run with: node src/scripts/testDeviceSessions.js
 *
 * Requires backend running and TEST_EMAIL / TEST_PASSWORD env vars.
 */
require('dotenv').config();
const crypto = require('crypto');

const baseUrl = process.env.API_BASE_URL || 'http://localhost:5000/api';
const email = process.env.TEST_EMAIL;
const password = process.env.TEST_PASSWORD;

const deviceA = crypto.randomUUID();
const deviceB = crypto.randomUUID();

const hashDeviceId = (deviceId) =>
  crypto.createHash('sha256').update(String(deviceId)).digest('hex');

const request = async (path, { method = 'GET', body, token, deviceId } = {}) => {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json().catch(() => ({}));
  return { status: response.status, data };
};

const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message);
  }
};

const run = async () => {
  if (!email || !password) {
    throw new Error('Set TEST_EMAIL and TEST_PASSWORD before running tests.');
  }

  console.log('1. Login device A (trusted after OTP)...');
  let loginA = await request('/auth/login', {
    method: 'POST',
    body: {
      email,
      password,
      deviceId: deviceA,
      deviceName: 'Device A',
      deviceType: 'android',
      operatingSystem: 'Android 15',
    },
  });
  if (loginA.status === 202) {
    const challengeId =
      loginA.data.data?.challengeId || loginA.data.data?.challenge_id;
    const otp = loginA.data.debug_otp;
    assert(challengeId, 'Missing challengeId for device A OTP flow');
    assert(otp, 'Enable ENABLE_DEBUG_OTP=true for automated OTP tests');
    loginA = await request('/auth/login/verify-device-otp', {
      method: 'POST',
      body: {
        challengeId,
        otp,
        deviceId: deviceA,
        deviceName: 'Device A',
        deviceType: 'android',
        operatingSystem: 'Android 15',
      },
    });
  }
  assert(loginA.status === 200, 'Device A login failed');
  const tokenA = loginA.data.access_token;
  const sessionA = loginA.data.session_id;
  assert(tokenA && sessionA, 'Device A tokens missing');

  console.log('2. Login device B should require OTP...');
  const loginB = await request('/auth/login', {
    method: 'POST',
    body: {
      email,
      password,
      deviceId: deviceB,
      deviceName: 'Device B',
      deviceType: 'ios',
      operatingSystem: 'iOS 18',
    },
  });
  assert(loginB.status === 202, 'Device B should require OTP');

  console.log('3. Device A lists both sessions after B verifies OTP...');
  const challengeIdB =
    loginB.data.data?.challengeId || loginB.data.data?.challenge_id;
  const otpB = loginB.data.debug_otp;
  assert(challengeIdB && otpB, 'Missing OTP challenge for device B');
  const verifyB = await request('/auth/login/verify-device-otp', {
    method: 'POST',
    body: {
      challengeId: challengeIdB,
      otp: otpB,
      deviceId: deviceB,
      deviceName: 'Device B',
      deviceType: 'ios',
      operatingSystem: 'iOS 18',
    },
  });
  assert(verifyB.status === 200, 'Device B OTP verify failed');
  const tokenB = verifyB.data.access_token;
  const sessionB = verifyB.data.session_id;

  const devicesA = await request('/auth/devices', { token: tokenA });
  assert(devicesA.status === 200, 'Device list failed');
  assert(devicesA.data.data.length >= 2, 'Expected at least 2 active devices');

  console.log('4. Device A revokes device B...');
  const revoke = await request(`/auth/devices/${sessionB}`, {
    method: 'DELETE',
    token: tokenA,
  });
  assert(revoke.status === 200, 'Revoke device B failed');

  console.log('5. Device B API call returns SESSION_REVOKED...');
  const blocked = await request('/auth/devices', { token: tokenB });
  assert(blocked.status === 401, 'Device B should be unauthorized');
  assert(
    blocked.data.errorCode === 'SESSION_REVOKED',
    'Expected SESSION_REVOKED for device B'
  );

  console.log('6. Device A still works...');
  const stillOk = await request('/auth/devices', { token: tokenA });
  assert(stillOk.status === 200, 'Device A should remain logged in');

  console.log('7. Device B login again requires OTP...');
  const reloginB = await request('/auth/login', {
    method: 'POST',
    body: {
      email,
      password,
      deviceId: deviceB,
      deviceName: 'Device B',
      deviceType: 'ios',
      operatingSystem: 'iOS 18',
    },
  });
  assert(reloginB.status === 202, 'Revoked device B must require OTP again');

  console.log('All device session checks passed.');
};

run().catch((error) => {
  console.error('Device session tests failed:', error.message);
  process.exit(1);
});
