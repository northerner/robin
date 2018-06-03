module Model exposing (..)

import OAuth

type alias Model =
    { token: Maybe OAuth.Token
    , config: Config
    , track: Maybe Track
    , trackURI: Maybe String
    , user: Maybe User
    }

type alias Config =
    { spotify_client_id: String
    , site_uri: String
    }

type alias Track =
    { artist: String
    , title: String
    , albumCoverUrl: String
    , progressMs: Float
    , durationMs: Float
    , isPlaying: Bool
    }

type alias User =
    { uid: String }
