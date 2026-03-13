export const FIREBASE_CONFIG = {
  apiKey: 'AIzaSyCTmhiI21zlCD89amuEPOLjIF4SnkEjiJ4',
  authDomain: 'lpm-participatory-budgeting.firebaseapp.com',
  databaseURL: 'https://lpm-participatory-budgeting-default-rtdb.firebaseio.com',
  projectId: 'lpm-participatory-budgeting',
  storageBucket: 'lpm-participatory-budgeting.firebasestorage.app',
  messagingSenderId: '876127187573',
  appId: '1:876127187573:web:d08a6b4749e1807e983e3c'
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
