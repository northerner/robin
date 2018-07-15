port module OutsideInfo exposing (..)

import Model exposing (User, Channel)

import Json.Decode exposing (decodeValue, map, map2, map3, field, string, maybe)
import Json.Encode as Encode


sendInfoOutside : InfoForOutside -> Cmd msg
sendInfoOutside info =
    case info of
        SignInToFirebase ->
            infoForOutside { tag = "SignInToFirebase", data = Encode.null }

        LogError err ->
            infoForOutside { tag = "LogError", data = Encode.string err }

        Broadcast trackURI ->
            infoForOutside { tag = "Broadcast", data = Encode.string trackURI }

        GetChannels ->
            infoForOutside { tag = "GetChannels", data = Encode.null }

        CreateOrUpdateChannel channel ->
            infoForOutside { tag = "CreateOrUpdateChannel", data = channelEncoder channel }

        ChangeChannel channel ->
            infoForOutside { tag = "ChangeChannel", data = Encode.string channel.ownerUID }

        GetUserChannel user ->
            infoForOutside { tag = "GetUserChannel", data = Encode.string user.uid }

getInfoFromOutside : (InfoForElm -> msg) -> (String -> msg) -> Sub msg
getInfoFromOutside tagger onError =
    infoForElm
        (\outsideInfo ->
            case outsideInfo.tag of
                "NewTrack" ->
                    case decodeValue Json.Decode.string outsideInfo.data of
                        Ok trackURI ->
                            tagger <| NewTrack trackURI

                        Err e ->
                            onError e

                "NewUser" ->
                    case decodeValue channelDecoder outsideInfo.data of
                        Ok user ->
                            tagger <| NewUser user

                        Err e ->
                            onError e

                "AllChannels" ->
                    case decodeValue (Json.Decode.list channelDecoder) outsideInfo.data of
                        Ok channels ->
                            tagger <| AllChannels channels

                        Err e ->
                            onError e

                "UpdateUserChannel" ->
                    case decodeValue channelDecoder outsideInfo.data of
                        Ok channel ->
                            tagger <| UpdateUserChannel channel

                        Err e ->
                            onError e

                _ ->
                    onError <| "Unexpected info from outside: " ++ toString outsideInfo
        )

channelDecoder =
    map3 Channel
        (maybe (field "nowPlayingURI" string))
        (field "ownerUID" string)
        (field "name" string)

channelEncoder : Channel -> Encode.Value
channelEncoder channel =
    Encode.object
        [ ("nowPlayingURI", Encode.string (Maybe.withDefault "" channel.nowPlayingURI))
        , ("name", Encode.string channel.name)
        ]

type InfoForOutside
    = SignInToFirebase
    | LogError String
    | Broadcast String
    | GetChannels
    | CreateOrUpdateChannel Channel
    | ChangeChannel Channel
    | GetUserChannel User

type InfoForElm
    = NewTrack String
    | NewUser Channel
    | AllChannels (List Channel)
    | UpdateUserChannel Channel


type alias GenericOutsideData =
    { tag : String, data : Encode.Value }


port infoForOutside : GenericOutsideData -> Cmd msg
port infoForElm : (GenericOutsideData -> msg) -> Sub msg
