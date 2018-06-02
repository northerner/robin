port module Main exposing (..)

import Html exposing (Html, text, div, h1, h2, img, button, p, input)
import Html.Attributes exposing (src, style, disabled, placeholder, type_)
import Html.Events exposing (onClick, onInput)
import OAuth
import OAuth.Implicit
import Navigation
import Http
import Json.Decode exposing (int, string, float, bool, Decoder, map6, at, index, andThen, field)
import Json.Encode as Encode
import Time exposing (Time)
import Task exposing (Task)
import Process


---- MODEL ----


type alias Model =
    { token: Maybe OAuth.Token
    , config: Config
    , track: Maybe Track
    , trackURI: Maybe String
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


trackDecoder =
    map6 Track
        (at ["item", "artists"] (index 0 (field "name" string)))
        (at ["item", "name"] string)
        (at ["item", "album", "images"] (index 0 (field "url" string)))
        (field "progress_ms" float)
        (at ["item", "duration_ms"] float)
        (field "is_playing" bool)

init : Config -> Navigation.Location -> ( Model, Cmd Msg )
init config location =
    case OAuth.Implicit.parse location of
        Ok { token, expiresIn } ->
            let
                model = { token = Just token, config = config, track = Nothing, trackURI = Nothing }

                timeoutIn =
                    case expiresIn of
                        Just timeout -> toFloat timeout
                        _ -> 3600.0

                startAuthTimeout =
                    Process.sleep (Time.second * timeoutIn)
                    |> Task.perform (always RedirectToSignin)

                startPlayingTimeout =
                    Task.perform (always GetPlaying) (Task.succeed ())

            in
                (model , Cmd.batch [ startAuthTimeout, startPlayingTimeout ] )
        Err _ ->
            ( { token = Nothing, config = config, track = Nothing, trackURI = Nothing }, Cmd.none )


---- UPDATE ----


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



-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.track of
              Just track ->
                  case track.isPlaying of
                      True ->
                          Time.every (Time.second) Tick
                      _ ->
                          Sub.none
              _ ->
                  Sub.none
        ,  newTrack PlayThis
        ]

port newTrack: (Maybe String -> msg) -> Sub msg

---- VIEW ----


view : Model -> Html Msg
view model =
    let
        toCssUrl url =
            "url(" ++ url ++ ")"

        controls =
            case (model.token, model.track) of
                (Nothing, Nothing) ->
                    [ button [ onClick Authorize ] [ text "Sign in" ] ]
                (_, Just track) ->
                    [ div [] [ button [ onClick (Control Previous) ] [ text "Previous" ]
                             , button [ onClick (Control Play) ] [ text "Play" ]
                             , button [ onClick (Control Pause) ] [ text "Pause" ]
                             , button [ onClick (Control Next) ] [ text "Next" ] ]
                    , div [] [ input [ type_ "text", placeholder "Spotify track ID", onInput SetTrackURI ] []
                             , button [ onClick (PlayThis model.trackURI) ] [ text "Play this!" ] ] ]
                _ ->
                    []

        progress track =
            text ((toString (track.progressMs / 1000)) ++ " / " ++ (toString (track.durationMs / 1000)))

        playing =
            case model.track of
                Just track ->
                    [ p [] [ text (track.artist ++ " - " ++ track.title) ]
                    , p [] [ progress track ]
                    , div [ style [ ("background", toCssUrl track.albumCoverUrl)
                                  , ("background-size", "cover")
                                  , ("background-position", "center")
                                  , ("background-repeat", "no-repeat")
                                  , ("min-height", "60vh")
                                  ]] []]
                Nothing ->
                    []

    in
      div []
          [ h1 [] [ text "Robin" ]
          , div [] controls
          , div [] playing
          ]



---- PROGRAM ----


main : Program Config Model Msg
main =
    Navigation.programWithFlags
        (always NoOp)
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
