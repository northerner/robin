module View exposing (..)

import Model exposing (Model, Config, Track)
import Update exposing (..)

import Html.Styled.Events exposing (onClick, onInput)
import Css exposing (..)
import Css.Colors as Colors
import Html.Styled exposing (styled, Html, Attribute, text, div, h1, h2, img, button, p, input, span)
import Html.Styled.Attributes exposing (css, href, src, style, disabled, placeholder, type_, defaultValue)


theme : { secondary : Color, primary : Color }
theme =
    { primary = hex "4fc08d"
    , secondary = rgb 250 240 230
    }

btn : List (Html.Styled.Attribute msg) -> List (Html.Styled.Html msg) -> Html.Styled.Html msg
btn =
    styled Html.Styled.button
        [ margin (em 0.5)
        , border3 (px 1) solid theme.primary
        , borderRadius (em 2)
        , padding2 (em 0.75) (em 2)
        , backgroundColor Colors.white
        , hover
            [ backgroundColor theme.primary
            , color (rgb 250 250 250)
            ]
        ]

view : Model -> Html Msg
view model =
    let
        toCssUrl url =
            "url(" ++ url ++ ")"

        controls =
            case (model.token, model.track) of
                (Nothing, Nothing) ->
                    [ btn [ onClick Authorize ] [ text "Sign in with Spotify" ] ]
                (_, Just track) ->
                    [ div [] [ btn [ onClick (Control Play) ] [ text "Play" ]
                             , btn [ onClick (Control Pause) ] [ text "Pause" ]
                             ] ]
                _ ->
                    []

        progress track =
            styled div [ height (px 2)
                       , width (vw 50)
                       , backgroundColor Colors.black
                       ] [] [ styled div [ height (px 2)
                                         , width (vw ((track.progressMs / track.durationMs) * 50))
                                         , backgroundColor theme.primary
                                         ] [] []
                       ]

        playing =
            case model.track of
                Just track ->
                    [ p [] [ text (track.artist ++ " - " ++ track.title) ]
                    , p [] [ progress track ]
                    , img [ src track.albumCoverUrl ] []]
                Nothing ->
                    []

        searchResultView result =
            case model.user of
                Just user ->
                  p [] [ (btn [ onClick (CreateChannel user.channel.name result.trackURI)] [ text "Play" ])
                       , text result.name
                       ]
                _ ->
                  p [] []
        searchResults =
            case model.searchResults of
                [] ->
                    []
                results ->
                    List.map searchResultView results

        admin =
            case model.user of
                Just user ->
                    styled div [ border3 (px 1) solid theme.primary
                               , width (vw 40)
                               , padding (em 0.5)
                               , flexDirection column
                               , (property "display" "flex")
                               ] [] [ p [] [ text ("DJing channel " ++ user.channel.name) ]
                                    , input [ type_ "text"
                                            , placeholder "Spotify track ID"
                                            , defaultValue user.channel.nowPlayingURI
                                            , onInput SetTrackURI ] []
                                    , input [ type_ "text"
                                            , placeholder "Channel name"
                                            , defaultValue user.channel.name
                                            , onInput SetChannelName ] []
                                    , btn [ onClick (CreateChannel user.channel.name user.channel.nowPlayingURI) ] [ text "Update channel" ]
                                    , input [ type_ "text"
                                            , placeholder "Search"
                                            , defaultValue (Maybe.withDefault "" model.searchTerm)
                                            , onInput SetSearchTerm ] []
                                    , btn [ onClick (Search model.searchTerm) ] [ text "Search" ]
                                    , div [] searchResults ]
                _ ->
                    btn [ onClick SignInToFirebase ] [ text "Sign in to DJ" ]

        channelButton channel =
            btn [ onClick (SwitchChannel channel) ] [ text channel.name ]

        channels =
            case (model.channels.active, model.channels.inactive) of
                (Nothing, []) ->
                    [ btn [ onClick GetChannels ] [ text "Get channels" ] ]

                (Nothing, inactive) ->
                    [ span [] [ text "Channels" ] ]
                    ++ List.map channelButton inactive

                (Just active, inactive) ->
                    [ span [] [ text "Channels" ] ]
                    ++ List.map channelButton inactive
                    ++ [ styled span [ textDecoration underline ] [] [ text ("Tuned to: " ++ active.name) ] ]

    in
      styled div [ width (vw 100)
                 , flexDirection row
                 , flexWrap wrap
                 , alignItems center
                 , justifyContent spaceBetween
                 , (property "display" "flex")
                 ] [] [ styled div [ width (auto)
                                   , maxWidth (px 600)
                                   , padding (pc 2)
                                   , flexDirection column
                                   , alignItems center
                                   , (property "display" "flex")
                                   ] [] [ div [] channels
                                        , h1 [] [ text "NEW ADVENTURES IN SPOTI-FI" ]
                                        , div [] controls
                                        , div [] playing
                                        ]
                      , styled div [ width (auto)
                                   , minWidth (px 400)
                                   , padding (pc 2)
                                   , flexDirection column
                                   , alignItems center
                                   , (property "display" "flex")
                                   ] [] [ div [] [ admin ]
                                        ]]
