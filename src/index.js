import './main.css';
import { Main } from './Main.elm';
import registerServiceWorker from './registerServiceWorker';

//Main.embed(document.getElementById('root'));
Main.embed(document.getElementById('root'), {
  spotify_client_id: process.env.ELM_APP_SPOTIFY_CLIENT_ID,
  site_uri: process.env.ELM_APP_SITE_URI,
});

registerServiceWorker();
