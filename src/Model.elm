module Model exposing (..)

import OAuth

type alias Model =
    { token: Maybe OAuth.Token
    , config: Config
    , track: Maybe Track
    , trackURI: Maybe String
    , user: Maybe User
    , channels: ChannelList
    , channelName: Maybe String
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

type alias Channel =
    { nowPlayingURI: Maybe String
    , ownerUID: Maybe String
    , name: String }

type alias ChannelList =
    { active: Maybe Channel
    , inactive: List Channel }
