# config/initializers/oas_rails.rb
OasRails.configure do |config|
  # Basic Information about the API
  config.info.title = 'Inventory API'
  config.info.version = '1.0.0'
  config.info.summary = 'Simple Inventory Management System API'
  config.info.description = <<~HEREDOC
    # Inventory Management API

    A simple inventory management system that tracks products and their transactions.

    ## Features

    - Product stock management
    - Transaction tracking (in/out)
    - Stock validation for outbound transactions
    - Pagination support with headers
    - Filtering and sorting via Ransack

    ## Pagination

    All list endpoints support pagination via query parameters:
    - `page`: Page number (default: 1)
    - `per_page`: Items per page (default: 20, max: 100)

    Pagination metadata is returned in response headers:
    - `page`: Current page number
    - `per-page`: Items per page
    - `total`: Total number of items
    - `total-pages`: Total number of pages

    ## Filtering and Sorting

    Transactions can be filtered and sorted using Ransack query parameters:
    - `q[product_id_eq]=1`: Filter by product ID
    - `q[transaction_type_eq]=in`: Filter by transaction type
    - `q[quantity_gt]=10`: Filter by quantity greater than
    - `q[s]=created_at desc`: Sort by created_at descending
  HEREDOC
  config.info.contact.name = 'Inventory API Team'
  config.info.contact.email = 'api@inventory.local'

  # Servers Information. For more details follow: https://spec.openapis.org/oas/latest.html#server-object
  config.servers = [{ url: 'http://localhost:3000', description: 'Development Server' }]

  # Tag Information. For more details follow: https://spec.openapis.org/oas/latest.html#tag-object
  config.tags = [
    { name: "Products", description: "Manage products and view inventory levels" },
    { name: "Transactions", description: "Manage inventory transactions" }
  ]

  # Optional Settings (Uncomment to use)

  # Extract default tags of operations from namespace or controller. Can be set to :namespace or :controller
  # config.default_tags_from = :namespace

  # Automatically detect request bodies for create/update methods
  # Default: true
  # config.autodiscover_request_body = false

  # Automatically detect responses from controller renders
  # Default: true
  # config.autodiscover_responses = false

  # API path configuration if your API is under a different namespace
  # config.api_path = "/"

  # Apply your custom layout. Should be the name of your layout file
  # Example: "application" if file named application.html.erb
  # Default: false
  # config.layout = "application"

  # Excluding custom controllers or controllers#action
  # Example: ["projects", "users#new"]
  # config.ignored_actions = []

  # #######################
  # Authentication Settings
  # #######################

  # Whether to authenticate all routes by default
  # Default is true; set to false if you don't want all routes to include security schemas by default
  config.authenticate_all_routes_by_default = false

  # Default security schema used for authentication
  # Choose a predefined security schema
  # [:api_key_cookie, :api_key_header, :api_key_query, :basic, :bearer, :bearer_jwt, :mutual_tls]
  # config.security_schema = :bearer

  # Custom security schemas
  # You can uncomment and modify to use custom security schemas
  # Please follow the documentation: https://spec.openapis.org/oas/latest.html#security-scheme-object
  #
  # config.security_schemas = {
  #  bearer:{
  #   "type": "apiKey",
  #   "name": "api_key",
  #   "in": "header"
  #  }
  # }

  # ###########################
  # Default Responses (Errors)
  # ###########################

  # The default responses errors are set only if the action allow it.
  # Example, if you add forbidden then it will be added only if the endpoint requires authentication.
  # Example: not_found will be setted to the endpoint only if the operation is a show/update/destroy action.
  # config.set_default_responses = true
  # config.possible_default_responses = [:not_found, :unauthorized, :forbidden, :internal_server_error, :unprocessable_entity]
  # config.response_body_of_default = "Hash{ message: String }"
  # config.response_body_of_unprocessable_entity= "Hash{ errors: Array<String> }"
end
