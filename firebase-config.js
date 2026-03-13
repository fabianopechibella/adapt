export const FIREBASE_CONFIG = {
  apiKey: 'SUA_API_KEY',
  authDomain: 'SEU-PROJETO.firebaseapp.com',
  databaseURL: 'https://SEU-PROJETO-default-rtdb.firebaseio.com',
  projectId: 'SEU-PROJETO',
  storageBucket: 'SEU-PROJETO.appspot.com',
  messagingSenderId: 'SEU_MESSAGING_SENDER_ID',
  appId: 'SEU_APP_ID'
}

export function validateFirebaseConfig(config) {
  return config !== null &&
    typeof config === 'object' &&
    typeof config.apiKey === 'string' &&
    config.apiKey.length > 0 &&
    !config.apiKey.includes('SUA_API_KEY') &&
    typeof config.databaseURL === 'string' &&
    config.databaseURL.startsWith('https://') &&
    config.databaseURL.includes('firebaseio.com') &&
    !config.databaseURL.includes('SEU-PROJETO') &&
    typeof config.projectId === 'string' &&
    config.projectId.length > 0 &&
    !config.projectId.includes('SEU-PROJETO')
}
