defmodule Demo.Blog.Post do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo Demo.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :content, :string do
      allow_nil? true
      public? true
    end

    attribute :published, :boolean do
      default false
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :category, Demo.Blog.Category do
      allow_nil? true
      public? true
    end
  end

  calculations do
    calculate :word_count, :integer do
      public? true

      calculation fn records, _context ->
        Enum.map(records, fn record ->
          case record.content do
            nil -> 0
            content -> content |> String.split(~r/\s+/) |> Enum.reject(&(&1 == "")) |> length()
          end
        end)
      end
    end
  end

  actions do
    default_accept [:title, :content, :published, :category_id]

    defaults [:create, :read, :update, :destroy]

    action :send_email, :struct do
      constraints instance_of: __MODULE__

      argument :post_id, :uuid do
        allow_nil? false
      end

      argument :email, :string do
        allow_nil? false
      end

      run fn input, context ->
        post_id = input.arguments.post_id
        email = input.arguments.email

        # Load the post
        post = Ash.get!(__MODULE__, post_id, domain: context.domain)

        # Mock sending email
        {:ok, post}
      end
    end

    # New resource actions for demo
    action :send_newsletter, :struct do
      argument :subject, :string do
        allow_nil? false
      end

      argument :content, :string do
        allow_nil? false
      end

      argument :recipient_emails, {:array, :string} do
        allow_nil? true
        default []
      end

      argument :send_at, :datetime do
        allow_nil? true
      end

      run fn input, _context ->
        # Mock newsletter sending
        {:ok, %{sent: length(input.arguments.recipient_emails)}}
      end
    end

    action :import_posts, :struct do
      argument :csv_file, Ash.Type.File do
        allow_nil? false
      end

      argument :category_id, :uuid do
        allow_nil? true
      end

      argument :publish_imported, :boolean do
        default false
      end

      run fn input, context ->
        csv_file = input.arguments.csv_file

            # Read file contents
            case Ash.Type.File.open(csv_file, [:read, :utf8]) do
              {:ok, io_device} ->
                # Read and display file contents
                contents = IO.read(io_device, :eof)
                :ok = File.close(io_device)

                # Count lines
                lines = String.split(contents, "\n", trim: true)

                {:ok, %{
                  imported: length(lines) - 1,  # Assuming first line is header
                  file_size: byte_size(contents),
                }}

              {:error, reason} ->
                {:error, "Failed to open CSV file: #{inspect(reason)}"}
            end
      end
    end

    action :generate_report, :struct do
      argument :report_type, :atom do
        allow_nil? false
        constraints one_of: [:monthly_summary, :category_breakdown, :author_stats]
      end

      argument :start_date, :date do
        allow_nil? false
      end

      argument :end_date, :date do
        allow_nil? false
      end

      argument :include_drafts, :boolean do
        default true
      end

      run fn input, _context ->
        # Mock report generation
        report_type = input.arguments.report_type

        {:ok, %{
          report_type: report_type,
          total_posts: 42,
          date_range: "#{input.arguments.start_date} - #{input.arguments.end_date}"
        }}
      end
    end

    action :assign_category, :struct do
      argument :category_id, :uuid do
        allow_nil? false
      end

      run fn input, context ->
        # Mock bulk category assignment
        # In a real implementation, you would:
        # 1. Query posts based on conditions
        # 2. Update their category_id

        {:ok, %{updated: 10}}  # Mock result
      end
    end
  end
end
