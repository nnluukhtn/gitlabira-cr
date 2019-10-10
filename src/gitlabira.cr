# TODO: Write documentation for `Gitlabira`'
require "kemal"
require "logger"
require "base64"
require "http/client"
require "raven"
require "raven/integrations/kemal"

# Perform basic raven configuration, none of it is required though
Raven.configure do |config|
  # Keep main fiber responsive by sending the events in the background
  config.async = true
  # Set the environment name using `Kemal.config.env`, which uses `KEMAL_ENV` variable under-the-hood
  config.current_environment = Kemal.config.env
end

# Replace the built-in `Kemal::LogHandler` with a
# dedicated `Raven::Kemal::LogHandler`, capturing all
# sent messages and requests as Sentry breadcrumbs

# If you'd like to preserve default logging provided by
# Kemal, pass `Kemal::LogHandler.new` to the constructor
if Kemal.config.logging
  Kemal.config.logger = Raven::Kemal::LogHandler.new(Kemal::LogHandler.new)
else
  Kemal.config.logger = Raven::Kemal::LogHandler.new
end

# Add raven's exception handler in order to capture
# all unhandled exceptions thrown inside your routes.
# Captured exceptions are re-raised afterwards
Kemal.config.add_handler Raven::Kemal::ExceptionHandler.new

module Gitlabira
  VERSION = "0.1.0"

  PUSH_EVENT = :push_event
  MERGE_REQUEST_EVENT = :merge_request_event
  GITLAB_EVENT_MAPPING = {
    "Push Hook" => PUSH_EVENT,
    "Merge Request Hook" => MERGE_REQUEST_EVENT
  }
  JIRA_BRANCH_REGEX = /[A-Z]+-\d+/
  GITLAB_REF_PREFIX = "refs/heads/"

  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::INFO

  private def self.jira_authentication_header
    encoded_string = Base64.strict_encode("#{ENV["JIRA_USER_NAME"]}:#{ENV["JIRA_PASSWORD"]}")
    "Basic #{encoded_string}"
  end

  private def self.transit_jira_issue(jira_issue_id, transition_id)
    response = HTTP::Client.post(
      "#{ENV["JIRA_PROJECT_ENDPOINT"]}/rest/api/2/issue/#{jira_issue_id}/transitions",
      headers: HTTP::Headers{
        "Content-Type" => "application/json",
        "Authorization" => jira_authentication_header
      },
      body: {
        "transition": { "id": transition_id }
      }.to_json
    )
    if response.status == 204
      @@logger.info ">>>>> Successfully transit issue: #{jira_issue_id} to transition: #{transition_id}"
    else
      @@logger.error ">>>>> Failed to transit issue: #{jira_issue_id} to transition: #{transition_id}"
      @@logger.error ">>>>> Reason: #{response.body}"
    end
  end

  private def self.push_event_handler(env)
    json_params = env.params.json
    ref = json_params["ref"].as(String)
    branch = ref.sub(GITLAB_REF_PREFIX, "")
    result = branch.match(JIRA_BRANCH_REGEX)
    if result
      ticket_code = result.to_a.first
      transit_jira_issue(ticket_code, ENV["JIRA_START_DEVELOPMENT_TRANSITION"])
    else
      @@logger.info ">>>>> Branch is not followed regex, ignoring"
    end
  end

  private def self.gitlab_event(env)
    env.request.headers["X-Gitlab-Event"]?
  end

  private def self.merge_request_event_handler(env)
    json_params = env.params.json
    object_attributes = json_params["object_attributes"].as(Hash)
    source_branch = object_attributes["source_branch"].as_s
    mr_state = object_attributes["state"].as_s
    result = source_branch.match(JIRA_BRANCH_REGEX)
    if result
      ticket_code = result.to_a.first
      case mr_state
      when "opened"
        transit_jira_issue(ticket_code, ENV["JIRA_TO_REVIEW_TRANSITION"])
      when "closed"
        transit_jira_issue(ticket_code, ENV["JIRA_IN_DEVELOPMENT_TRANSITION"])
      when "merged"
        transit_jira_issue(ticket_code, ENV["JIRA_TO_QA_TRANSITION"])
      end
    else
      @@logger.info ">>>>> Branch is not followed regex, ignoring"
    end
  end


  post "/hook" do |env|
    @@logger.info ">>>>> Request params: #{env.params.json}"
    @@logger.info ">>>>> Request headers: #{env.request.headers}"
    gitlab_event = self.gitlab_event(env)
    @@logger.info ">>>>> Gitlab event: #{gitlab_event || "NULL"}"

    case GITLAB_EVENT_MAPPING[gitlab_event]
    when PUSH_EVENT
      push_event_handler(env)
    when MERGE_REQUEST_EVENT
      merge_request_event_handler(env)
    end

    "OK"
  end

  get "/health" do
    "OK"
  end
end

Kemal.run
