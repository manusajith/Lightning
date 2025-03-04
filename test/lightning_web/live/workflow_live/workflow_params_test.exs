defmodule LightningWeb.WorkflowNewLive.WorkflowParamsTest do
  use ExUnit.Case, async: true

  alias LightningWeb.WorkflowNewLive.WorkflowParams
  alias Lightning.Workflows.Workflow

  setup do
    job_1_id = Ecto.UUID.generate()
    job_2_id = Ecto.UUID.generate()
    trigger_1_id = Ecto.UUID.generate()

    params = %{
      "name" => nil,
      "project_id" => nil,
      "jobs" => [
        %{"id" => job_1_id, "name" => ""},
        %{"id" => job_2_id, "name" => "job-2"}
      ],
      "triggers" => [
        %{"id" => trigger_1_id, "type" => "webhook"}
      ],
      "edges" => [
        %{
          "id" => Ecto.UUID.generate(),
          "source_trigger_id" => trigger_1_id,
          "condition" => "on_job_failure",
          "target_job_id" => job_1_id
        },
        %{
          "id" => Ecto.UUID.generate(),
          "source_job_id" => job_1_id,
          "condition" => "on_job_success",
          "target_job_id" => job_2_id
        }
      ]
    }

    %{
      params: params,
      job_1_id: job_1_id,
      job_2_id: job_2_id,
      trigger_1_id: trigger_1_id
    }
  end

  describe "to_map/1" do
    test "creates a serializable map for a Workflow changeset", %{
      params: params,
      job_1_id: job_1_id,
      job_2_id: job_2_id,
      trigger_1_id: trigger_1_id
    } do
      changeset = %Workflow{} |> Workflow.changeset(params)

      assert %{
               "edges" => [
                 %{
                   "condition" => "on_job_failure",
                   "errors" => %{},
                   "id" => _,
                   "source_job_id" => nil,
                   "source_trigger_id" => ^trigger_1_id,
                   "target_job_id" => ^job_1_id
                 },
                 %{
                   "condition" => "on_job_success",
                   "errors" => %{},
                   "id" => _,
                   "source_job_id" => ^job_1_id,
                   "source_trigger_id" => nil,
                   "target_job_id" => ^job_2_id
                 }
               ],
               "jobs" => [
                 %{
                   "errors" => %{"name" => ["can't be blank"]},
                   "id" => ^job_1_id,
                   "name" => ""
                 },
                 %{
                   "errors" => %{},
                   "id" => ^job_2_id,
                   "name" => "job-2"
                 }
               ],
               "triggers" => [
                 %{
                   "errors" => %{},
                   "id" => ^trigger_1_id,
                   "type" => "webhook"
                 }
               ]
             } = changeset |> WorkflowParams.to_map()
    end

    test "creates a serializable map for a Workflow changeset that already has associations",
         %{
           params: params,
           job_1_id: job_1_id,
           job_2_id: job_2_id,
           trigger_1_id: trigger_1_id
         } do
      changeset =
        %Workflow{}
        |> Workflow.changeset(params)
        |> Ecto.Changeset.apply_changes()
        |> Workflow.changeset(%{
          "jobs" => [
            %{
              "id" => job_3_id = Ecto.UUID.generate(),
              "name" => "job-3"
            }
            | params["jobs"]
          ]
        })

      next_params = changeset |> WorkflowParams.to_map()

      assert %{
               "edges" => [
                 %{
                   "condition" => "on_job_failure",
                   "errors" => %{},
                   "id" => _,
                   "source_job_id" => nil,
                   "source_trigger_id" => ^trigger_1_id,
                   "target_job_id" => ^job_1_id
                 },
                 %{
                   "condition" => "on_job_success",
                   "errors" => %{},
                   "id" => _,
                   "source_job_id" => ^job_1_id,
                   "source_trigger_id" => nil,
                   "target_job_id" => ^job_2_id
                 }
               ],
               "jobs" => [
                 %{
                   "adaptor" => "@openfn/language-common@latest",
                   "body" => "",
                   "project_credential_id" => nil,
                   "enabled" => "true",
                   "errors" => %{"body" => ["can't be blank"]},
                   "name" => "job-3",
                   "id" => ^job_3_id
                 },
                 %{
                   "errors" => %{"name" => ["can't be blank"]},
                   "id" => ^job_1_id,
                   "project_credential_id" => nil,
                   "name" => ""
                 },
                 %{
                   "errors" => %{},
                   "id" => ^job_2_id,
                   "project_credential_id" => nil,
                   "name" => "job-2"
                 }
               ],
               "triggers" => [
                 %{
                   "errors" => %{},
                   "id" => ^trigger_1_id,
                   "type" => "webhook"
                 }
               ]
             } = next_params

      next_params =
        changeset
        |> Ecto.Changeset.apply_changes()
        |> Workflow.changeset(params |> Map.put("edges", []))
        |> WorkflowParams.to_map()

      assert %{
               "edges" => [],
               "jobs" => [
                 %{
                   "errors" => %{"name" => ["can't be blank"]},
                   "id" => ^job_1_id,
                   "name" => ""
                 },
                 %{
                   "errors" => %{},
                   "id" => ^job_2_id,
                   "name" => "job-2"
                 }
               ],
               "triggers" => [
                 %{
                   "errors" => %{},
                   "id" => ^trigger_1_id,
                   "type" => "webhook"
                 }
               ]
             } = next_params
    end
  end

  describe "to_patches/2" do
    setup %{params: params} do
      changeset = %Workflow{} |> Workflow.changeset(params)
      original_params = changeset |> WorkflowParams.to_map()

      params =
        changeset
        |> Ecto.Changeset.put_change(:jobs, [])
        |> WorkflowParams.to_map()

      %{
        original_params: original_params,
        params: params
      }
    end

    test "creates a list of patches for a Workflow changeset", %{
      original_params: original_params,
      params: params
    } do
      assert WorkflowParams.to_patches(original_params, params) ==
               [
                 # Remove when https://github.com/corka149/jsonpatch/issues/16
                 # is fixed and released.
                 %{op: "add", path: "/project_id", value: nil},
                 %{op: "add", path: "/name", value: nil},
                 %{op: "remove", path: "/jobs/1"},
                 %{op: "remove", path: "/jobs/0"}
               ]
    end
  end
end
