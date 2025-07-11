defmodule DemoWeb.ResourceActions.PostGenerateReport do
  use AshBackpex.ResourceAction

  backpex do
    resource Demo.Blog.Post
    action :generate_report
    label "Generate Report"
    title "Generate Blog Report"
    
    fields do
      field :report_type do
        module Backpex.Fields.Select
        label "Report Type"
        help_text "Select the type of report to generate"
        options fn _assigns ->
          [
            {"Monthly Summary", :monthly_summary},
            {"Category Breakdown", :category_breakdown},
            {"Author Statistics", :author_stats}
          ]
        end
      end
      
      field :start_date do
        module Backpex.Fields.Date
        label "Start Date"
        help_text "Report period start date"
      end
      
      field :end_date do
        module Backpex.Fields.Date
        label "End Date"
        help_text "Report period end date"
      end
      
      field :include_drafts do
        module Backpex.Fields.Boolean
        label "Include Draft Posts"
        help_text "Include unpublished posts in the report"
      end
    end
  end
  
  # Example of custom base_schema - demonstrates the feature
  @impl Backpex.ResourceAction
  def base_schema(_assigns) do
    types = %{
      report_type: :string,
      start_date: :date,
      end_date: :date,
      include_drafts: :boolean,
      # Additional fields not in arguments
      output_format: :string
    }
    
    # Default values
    data = %{
      include_drafts: true,
      output_format: "pdf"
    }
    
    {data, types}
  end
end