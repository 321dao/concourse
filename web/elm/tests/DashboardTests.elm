module DashboardTests exposing (all)

import Concourse
import Dashboard exposing (..)
import Html.Attributes as Attr
import Html.Styled as HS
import RemoteData
import Test exposing (..)
import Test.Html.Query as Query
import Test.Html.Selector exposing (attribute, class, tag)
import Test.Html.Event as Event
import Json.Encode as Encode exposing (Value)
import NewTopBar


updateModel : Msg -> Model -> Model
updateModel msg =
    Dashboard.update msg >> Tuple.first


queryView : Model -> Query.Single Msg
queryView =
    view
        >> HS.toUnstyled
        >> Query.fromHtml


all : Test
all =
    describe "Dashboard"
        [ test "sends a ShowSearchInput message when the '/' button is pressed" <|
            let
                simulatedEventObject : Value
                simulatedEventObject =
                    Encode.object
                        [ ( "key", Encode.string "/" )
                        , ( "code", Encode.string "Slash" )
                        ]
            in
                \_ ->
                    init
                        { title = always Cmd.none
                        }
                        { csrfToken = ""
                        , turbulencePath = ""
                        , search = ""
                        , highDensity = False
                        }
                        |> Tuple.first
                        |> queryView
                        |> Event.simulate (Event.custom "keypress" simulatedEventObject)
                        |> Event.expect (TopBarMsg NewTopBar.ShowSearchInput)
        , test "links to specific builds" <|
            \_ ->
                let
                    msg =
                        APIDataFetched <|
                            RemoteData.Success
                                ( 0
                                , ( { teams = [ { id = 0, name = "team" } ]
                                    , pipelines =
                                        [ { id = 0
                                          , name = "pipeline"
                                          , paused = False
                                          , public = True
                                          , teamName = "team"
                                          , groups = []
                                          }
                                        ]
                                    , jobs =
                                        [ { pipeline =
                                                { teamName = "team"
                                                , pipelineName = "pipeline"
                                                }
                                          , name = "job"
                                          , pipelineName = "pipeline"
                                          , teamName = "team"
                                          , nextBuild = Nothing
                                          , finishedBuild =
                                                Just
                                                    { id = 0
                                                    , name = "1"
                                                    , job = Just { teamName = "team", pipelineName = "pipeline", jobName = "job" }
                                                    , status = Concourse.BuildStatusSucceeded
                                                    , duration = { startedAt = Nothing, finishedAt = Nothing }
                                                    , reapTime = Nothing
                                                    }
                                          , transitionBuild = Nothing
                                          , paused = False
                                          , disableManualTrigger = False
                                          , inputs = []
                                          , outputs = []
                                          , groups = []
                                          }
                                        ]
                                    , resources = []
                                    , version = "0.0.0"
                                    }
                                  , Nothing
                                  )
                                )
                in
                    init
                        { title = always Cmd.none
                        }
                        { csrfToken = ""
                        , turbulencePath = ""
                        , search = ""
                        , highDensity = False
                        }
                        |> Tuple.first
                        |> update msg
                        |> Tuple.first
                        |> view
                        |> HS.toUnstyled
                        |> Query.fromHtml
                        |> Query.find
                            [ class "dashboard-team-group"
                            , attribute <| Attr.attribute "data-team-name" "team"
                            ]
                        |> Query.find
                            [ class "node"
                            , attribute <| Attr.attribute "data-tooltip" "job"
                            ]
                        |> Query.find
                            [ tag "a" ]
                        |> Query.has
                            [ attribute <| Attr.href "/teams/team/pipelines/pipeline/jobs/job/builds/1" ]
        ]
