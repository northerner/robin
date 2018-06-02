import './main.css';
import { Main } from './Main.elm';
import registerServiceWorker from './registerServiceWorker';

//Main.embed(document.getElementById('root'));
var app = Main.embed(document.getElementById('root'), {
  spotify_client_id: process.env.ELM_APP_SPOTIFY_CLIENT_ID,
  site_uri: process.env.ELM_APP_SITE_URI,
});

registerServiceWorker();


// Initialize Firebase
var config = {
      apiKey: process.env.ELM_APP_FIREBASE_API_KEY,
      authDomain: process.env.ELM_APP_FIREBASE_AUTH_DOMAIN,
      projectId: process.env.ELM_APP_FIREBASE_PROJECT_ID,
    };

firebase.initializeApp(config);
var db = firebase.firestore();
db.settings({timestampsInSnapshots: true});

db.collection("tracks").doc("now-playing")
  .onSnapshot(function(doc) {
    console.log("Current data: ", doc.data());
    app.ports.newTrack.send(doc.data().uri);
  });
