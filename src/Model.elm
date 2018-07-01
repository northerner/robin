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
    , searchTerm: Maybe String
    , searchResults: List SearchResult
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
    { uid: String
    , channel: Channel }

type alias Channel =
    { nowPlayingURI: Maybe String
    , ownerUID: String
    , name: String }

type alias ChannelList =
    { active: Maybe Channel
    , inactive: List Channel }

type alias SearchResult =
    { name: String
    , trackURI: String }
