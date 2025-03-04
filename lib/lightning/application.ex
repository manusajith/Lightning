defmodule Lightning.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Cachex.Spec

  @impl true
  def start(_type, _args) do
    # mnesia startup
    :mnesia.stop()
    :mnesia.create_schema([node()])
    :mnesia.start()
    Hammer.Backend.Mnesia.create_mnesia_table(disc_copies: [node()])
    :mnesia.wait_for_tables([:__hammer_backend_mnesia], 60_000)

    # Only add the Sentry backend if a dsn is provided.
    if Application.get_env(:sentry, :included_environments, []) |> Enum.any?(),
      do: Logger.add_backend(Sentry.LoggerBackend)

    adaptor_registry_childspec =
      {Lightning.AdaptorRegistry,
       Application.get_env(:lightning, Lightning.AdaptorRegistry, [])}

    adaptor_service_childspec =
      {Lightning.AdaptorService,
       [name: :adaptor_service]
       |> Keyword.merge(Application.get_env(:lightning, :adaptor_service, []))}

    auth_providers_cache_childspec =
      {Cachex,
       name: :auth_providers,
       warmers: [
         warmer(module: Lightning.AuthProviders.CacheWarmer)
       ]}

    events = [
      [:oban, :circuit, :open],
      [:oban, :circuit, :trip],
      [:oban, :job, :exception]
    ]

    :telemetry.attach_many(
      "oban-errors",
      events,
      &Lightning.ObanManager.handle_event/4,
      nil
    )

    :ok = Oban.Telemetry.attach_default_logger(:debug)

    topologies =
      if System.get_env("K8S_HEADLESS_SERVICE") do
        [
          k8s: [
            strategy: Cluster.Strategy.Kubernetes.DNS,
            config: [
              service: System.get_env("K8S_HEADLESS_SERVICE"),
              application_name: "lightning",
              polling_interval: 5_000
            ]
          ]
        ]
      else
        Application.get_env(:libcluster, :topologies)
      end

    children = [
      {Cluster.Supervisor, [topologies, [name: Lightning.ClusterSupervisor]]},
      {Lightning.Vault, Application.get_env(:lightning, Lightning.Vault, [])},
      # Start the Ecto repository
      Lightning.Repo,
      # Start Oban,
      {Oban, oban_opts()},
      # Start the Telemetry supervisor
      LightningWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Lightning.PubSub},
      auth_providers_cache_childspec,
      # Start the Endpoint (http/https)
      LightningWeb.Endpoint,
      adaptor_registry_childspec,
      adaptor_service_childspec,
      {Lightning.TaskWorker, name: :cli_task_worker}
      # Start a worker by calling: Lightning.Worker.start_link(arg)
      # {Lightning.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lightning.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LightningWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def oban_opts() do
    Application.get_env(:lightning, Oban)
  end
end
