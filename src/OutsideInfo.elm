port module OutsideInfo exposing (..)

import Model exposing (User)

import Json.Decode exposing (decodeValue, map, field, string)
import Json.Encode


sendInfoOutside : InfoForOutside -> Cmd msg
sendInfoOutside info =
    case info of
        SignInToFirebase ->
            infoForOutside { tag = "SignInToFirebase", data = Json.Encode.null }

        LogError err ->
            infoForOutside { tag = "LogError", data = Json.Encode.string err }

        Broadcast trackURI ->
            infoForOutside { tag = "Broadcast", data = Json.Encode.string trackURI }

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
                    case decodeValue userDecoder outsideInfo.data of
                        Ok user ->
                            tagger <| NewUser user

                        Err e ->
                            onError e

                _ ->
                    onError <| "Unexpected info from outside: " ++ toString outsideInfo
        )

userDecoder =
    map User
        (field "uid" string)


type InfoForOutside
    = SignInToFirebase
    | LogError String
    | Broadcast String


type InfoForElm
    = NewTrack String
    | NewUser User


type alias GenericOutsideData =
    { tag : String, data : Json.Encode.Value }


port infoForOutside : GenericOutsideData -> Cmd msg


port infoForElm : (GenericOutsideData -> msg) -> Sub msg
