defmodule LightningWeb.WorkflowLive.ManualWorkorder do
  @moduledoc false
  use LightningWeb, :component

  attr :id, :string, required: true
  attr :dataclips, :list, default: []
  attr :form, :map, required: true
  attr :disabled, :boolean, default: true

  def component(assigns) do
    assigns =
      assigns
      |> assign(
        selected_dataclip:
          with dataclip_id when not is_nil(dataclip_id) <-
                 Phoenix.HTML.Form.input_value(assigns.form, :dataclip_id),
               dataclip when not is_nil(dataclip) <-
                 Enum.find(assigns.dataclips, &match?(%{id: ^dataclip_id}, &1)) do
            dataclip
          end
      )

    ~H"""
    <.form
      for={@form}
      id={@form.id}
      phx-hook="SaveAndRunViaCtrlEnter"
      phx-change="manual_run_change"
      phx-submit="manual_run_submit"
      class="h-full flex flex-col gap-4"
    >
      <div class="">
        <div class="flex-grow">
          <.input
            type="select"
            field={@form[:dataclip_id]}
            options={@dataclips |> Enum.map(&{&1.id, &1.id})}
            prompt="Create a new dataclip"
            disabled={@disabled}
          />
        </div>
      </div>

      <div class="flex-0">
        <div class="flex flex-row">
          <div class="basis-1/2 font-semibold text-secondary-700 text-xs xl:text-base">
            Dataclip Type
          </div>
          <div class="basis-1/2 text-right">
            <Common.dataclip_type_pill type={
              (@selected_dataclip && @selected_dataclip.type) || :saved_input
            } />
          </div>
        </div>
        <div class="flex flex-row mt-4">
          <div class="basis-1/2 font-semibold text-secondary-700 text-xs xl:text-base ">
            State Assembly
          </div>
          <div class="text-right text-xs xl:text-sm">
            <%= if(not is_nil(@selected_dataclip) and @selected_dataclip.type == :http_request) do %>
              The JSON shown here is the <em>body</em>
              of an HTTP request. The state assembler will place this payload into
              <code>state.data</code>
              when the job is run, before adding <code>state.configuration</code>
              from your selected credential.
            <% else %>
              The state assembler will overwrite the <code>configuration</code>
              attribute below with the body of the currently selected credential.
            <% end %>
          </div>
        </div>
      </div>
      <div :if={@selected_dataclip} class="grow overflow-y-auto rounded-md">
        <.log_view dataclip={@selected_dataclip} class="" />
      </div>
      <div :if={is_nil(@selected_dataclip)} class="grow">
        <.input
          type="textarea"
          field={@form[:body]}
          disabled={@disabled}
          class="h-full pb-2"
          phx-debounce="300"
        />
      </div>
    </.form>
    """
  end

  attr :dataclip, :map, required: true
  attr :class, :string, default: nil

  defp log_view(assigns) do
    assigns = assigns |> assign(log: format_dataclip_body(assigns.dataclip))

    ~H"""
    <LightningWeb.RunLive.Components.log_view log={@log} class={@class} />
    """
  end

  defp format_dataclip_body(dataclip) do
    dataclip.body
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
    |> String.split("\n")
  end
end
