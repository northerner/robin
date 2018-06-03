module Update exposing (..)

import Model exposing (Model, Config, Track, User)
import OutsideInfo exposing (InfoForElm, sendInfoOutside)

import OAuth
import OAuth.Implicit
import Time exposing (Time)
import Http
import Navigation
import Process
import Json.Decode exposing (int, string, float, bool, Decoder, map, map6, at, index, andThen, field)
import Json.Encode as Encode

type Msg
    = NoOp
    | Authorize
    | Control (Control)
    | ControlResponse (Result Http.Error String)
    | GetPlaying
    | PlayingResponse (Result Http.Error Track)
    | RedirectToSignin
    | Tick Time
    | SetTrackURI String
    | PlayThis (Maybe String)
    | SignInToFirebase
    | Outside InfoForElm
    | LogErr String
    | Broadcast (Maybe String)


type Control
    = Play
    | Pause
    | Next
    | Previous

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Authorize ->
            model
                ! [ OAuth.Implicit.authorize
                        { clientId = model.config.spotify_client_id
                        , redirectUri = model.config.site_uri
                        , responseType = OAuth.Token -- Use the OAuth.Token response type
                        , scope = [ "user-modify-playback-state", "user-read-playback-state" ]
                        , state = Nothing
                        , url = "https://accounts.spotify.com/authorize"
                        }
                  ]

        Control control ->
            case model.token of
                Just token ->
                    updateControl control model token
                Nothing ->
                    model ! []


        ControlResponse (Ok resp) ->
            update GetPlaying model

        ControlResponse (Err _) ->
            update GetPlaying model

        GetPlaying ->
            case model.token of
                Just token ->
                    let
                        req =
                            Http.request
                                { method = "GET"
                                , body = Http.emptyBody
                                , headers = OAuth.use token []
                                , withCredentials = False
                                , url = "https://api.spotify.com/v1/me/player/currently-playing"
                                , expect = Http.expectJson trackDecoder
                                , timeout = Nothing
                                }
                    in
                        model ! [Process.sleep (Time.second * 2) |> (\a -> (Http.send PlayingResponse req))]
                Nothing ->
                  model ! []

        PlayingResponse (Ok track) ->
            ( { model | track = Just track }, Cmd.none )

        PlayingResponse (Err _) ->
            model ! []

        RedirectToSignin ->
            ( model, Navigation.load model.config.site_uri )

        Tick _ ->
            case model.track of
                Just track ->
                    let
                        newTrack = Just { track | progressMs = track.progressMs + 1000 }
                        pollForStatus =
                            track.progressMs > track.durationMs + 1000
                    in
                        case pollForStatus of
                            True ->
                                update GetPlaying model
                            False ->
                                { model | track = newTrack } ! [ Cmd.none ]
                Nothing ->
                    model ! []

        SetTrackURI trackURI ->
            ( { model | trackURI = Just trackURI }, Cmd.none )

        PlayThis trackURI ->
            case (model.token, trackURI) of
                (Just token, Just trackURI) ->
                    let
                        jsonBody =
                            Encode.object
                                [ ("uris", Encode.list [ Encode.string trackURI ] ) ]
                        req = controlRequest "play" token (Http.jsonBody jsonBody)
                    in
                        model ! [Http.send ControlResponse req]
                (_, _) ->
                    model ! []

        SignInToFirebase ->
            model ! [ sendInfoOutside OutsideInfo.SignInToFirebase ]

        Outside infoForElm ->
            case infoForElm of
                OutsideInfo.NewTrack trackURI ->
                    update (PlayThis (Just trackURI)) model

                OutsideInfo.NewUser user ->
                    { model | user = Just user } ! []

        LogErr err ->
            model ! [ sendInfoOutside (OutsideInfo.LogError err) ]

        Broadcast trackURI ->
            case (model.user, trackURI) of
                (Just user, Just trackURI) ->
                    model ! [ sendInfoOutside (OutsideInfo.Broadcast trackURI) ]
                (_, _) ->
                    model ! []


updateControl : Control -> Model -> OAuth.Token -> ( Model, Cmd Msg )
updateControl control model token =
    case (control, model.track) of
        (Play, Just track) ->
            let
                req = controlRequest "play" token Http.emptyBody
                playingTrack = Just { track | isPlaying = True }
            in
                { model | track = playingTrack } ! [Http.send ControlResponse req]

        (Pause, Just track) ->
            let
                req = controlRequest "pause" token Http.emptyBody
                pausedTrack = Just { track | isPlaying = False }
            in
                { model | track = pausedTrack } ! [Http.send ControlResponse req]

        (Next, _) ->
            let
                req = controlRequest "next" token Http.emptyBody
            in
                model ! [Http.send ControlResponse req]

        (Previous, _) ->
            let
                req = controlRequest "previous" token Http.emptyBody
            in
                model ! [Http.send ControlResponse req]

        (_, _) ->
            model ! []

controlRequest : String -> OAuth.Token -> Http.Body -> Http.Request String
controlRequest action token body =
    let
        method =
            case action of
                "next" -> "POST"
                "previous" -> "POST"
                _ -> "PUT"
    in
        Http.request
            { method = method
            , body = body
            , headers = OAuth.use token []
            , withCredentials = False
            , url = "https://api.spotify.com/v1/me/player/" ++ action
            , expect = Http.expectString
            , timeout = Nothing
            }

trackDecoder =
    map6 Track
        (at ["item", "artists"] (index 0 (field "name" string)))
        (at ["item", "name"] string)
        (at ["item", "album", "images"] (index 0 (field "url" string)))
        (field "progress_ms" float)
        (at ["item", "duration_ms"] float)
        (field "is_playing" bool)
