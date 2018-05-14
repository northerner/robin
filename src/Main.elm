module Main exposing (..)

import Html exposing (Html, text, div, h1, h2, img, button, p)
import Html.Attributes exposing (src, style, disabled)
import Html.Events exposing (onClick)
import OAuth
import OAuth.Implicit
import Navigation
import Http
import Json.Decode exposing (int, string, float, bool, Decoder, map6, at, index, andThen, field)
import Time exposing (Time)
import Task exposing (Task)
import Process


---- MODEL ----


type alias Model =
    { token: Maybe OAuth.Token
    , config: Config
    , track: Maybe Track
    }

type alias Config =
    { spotify_client_id: String
    , site_uri: String
    }

type alias Track =
    { artist: String
    , title: String
    , albumCoverUrl: String
    , progressMs: Int
    , durationMs: Int
    , isPlaying: Bool
    }


trackDecoder =
    map6 Track
        (at ["item", "artists"] (index 0 (field "name" string)))
        (at ["item", "name"] string)
        (at ["item", "album", "images"] (index 0 (field "url" string)))
        (field "progress_ms" int)
        (at ["item", "duration_ms"] int)
        (field "is_playing" bool)

init : Config -> Navigation.Location -> ( Model, Cmd Msg )
init config location =
    case OAuth.Implicit.parse location of
        Ok { token, expiresIn } ->
            let
                model = { token = Just token, config = config, track = Nothing }

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
            ( { token = Nothing, config = config, track = Nothing }, Cmd.none )


---- UPDATE ----


type Msg
    = NoOp
    | Authorize
    | Control (Control)
    | ControlResponse (Result Http.Error String)
    | GetPlaying
    | PlayingResponse (Result Http.Error Track)
    | RedirectToSignin


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
            model ! []

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
                        model ! [Process.sleep Time.second |> (\a -> (Http.send PlayingResponse req))]
                Nothing ->
                  model ! []

        PlayingResponse (Ok track) ->
            ( { model | track = Just track }, Cmd.none )

        PlayingResponse (Err _) ->
            model ! []

        RedirectToSignin ->
            ( model, Navigation.load model.config.site_uri )


updateControl : Control -> Model -> OAuth.Token -> ( Model, Cmd Msg )
updateControl control model token =
    case control of
        Play ->
            let
                req = controlRequest "play" token
            in
                model ! [Http.send ControlResponse req]

        Pause ->
            let
                req = controlRequest "pause" token
            in
                model ! [Http.send ControlResponse req]

        Next ->
            let
                req = controlRequest "next" token
            in
                model ! [Http.send ControlResponse req]

        Previous ->
            let
                req = controlRequest "previous" token
            in
                model ! [Http.send ControlResponse req]

controlRequest : String -> OAuth.Token -> Http.Request String
controlRequest action token =
    let
        method =
            case action of
                "next" -> "POST"
                "previous" -> "POST"
                _ -> "PUT"
    in
        Http.request
            { method = method
            , body = Http.emptyBody
            , headers = OAuth.use token []
            , withCredentials = False
            , url = "https://api.spotify.com/v1/me/player/" ++ action
            , expect = Http.expectString
            , timeout = Nothing
            }


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
                    [ button [ onClick (Control Previous) ] [ text "Previous" ]
                    , button [ onClick (Control Play), disabled track.isPlaying ] [ text "Play" ]
                    , button [ onClick (Control Pause), disabled (not track.isPlaying)] [ text "Pause" ]
                    , button [ onClick (Control Next) ] [ text "Next" ] ]
                _ ->
                    []

        playing =
            case model.track of
                Just track ->
                    [ p [] [ text (track.artist ++ " - " ++ track.title) ]
                    , p [] [ text (toString track.progressMs ++ " / " ++ toString track.durationMs) ]
                    , div [ style [ ("background", toCssUrl track.albumCoverUrl)
                                  , ("background-size", "cover")
                                  , ("background-position", "center")
                                  , ("background-repeat", "no-repeat")
                                  , ("min-height", "60vh")
                                  ]] []]
                Nothing ->
                    [ p [ onClick GetPlaying ] [ text "Click for track name" ] ]
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
        , subscriptions = always Sub.none
        }
