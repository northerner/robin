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
    //app.ports.infoForElm.send({ tag: "NewTrack", data: doc.data().uri });
  });


app.ports.infoForOutside.subscribe(msg => {
  if (msg.tag == "LogError") {
    console.error(msg.data);
  } else if (msg.tag == "SignInToFirebase") {
    var provider = new firebase.auth.GoogleAuthProvider();
    firebase.auth().signInWithPopup(provider)
    .then(function(result) {
      db.collection("channels").doc(result.user.uid)
      .onSnapshot(function(doc) {
        app.ports.infoForElm.send({ tag: "NewUser", data: { ownerUID: result.user.uid, name: (doc.name || "New"), nowPlayingURI: (doc.nowPlayingURI || "fakeURI")  } });
      })
    }).catch(function(error) {
      console.log(error);
    });
  } else if (msg.tag == "Broadcast") {
    db.collection("tracks").doc("now-playing").update({uri: msg.data})
  } else if (msg.tag == "GetChannels") {
    db.collection("channels").where("name", ">=", "0").onSnapshot(function(querySnapshot) {
      app.ports.infoForElm.send({ tag: "AllChannels",
                                  data: querySnapshot.docs.map(doc => {
                                    const data = doc.data()
                                    return Object.assign({}, data, { ownerUID: doc.id })
                                  } ) });
    });
  } else if (msg.tag == "CreateOrUpdateChannel") {
    const user = firebase.auth().currentUser.uid
    db.collection("channels")
      .doc(user).set(msg.data).catch(function(error) {
        console.log(error);
    });
  } else if (msg.tag == "ChangeChannel") {
    db.collection("channels").doc(msg.data)
      .onSnapshot(function(doc) {
        // TODO: Refactor out newtrack interface to one updating the playing song in current channel
        app.ports.infoForElm.send({ tag: "NewTrack", data: doc.data().nowPlayingURI});
      });
  } else if (msg.tag == "GetUserChannel") {
    db.collection("channels").doc(msg.data)
      .onSnapshot(function(doc) {
        app.ports.infoForElm.send({ tag: "UpdateUserChannel",
                                    data: Object.assign({}, doc.data(), { ownerUID: doc.id })
                                  });
      });
  }

});

