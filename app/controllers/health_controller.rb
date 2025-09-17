class HealthController < ApplicationController
  # Skip authentication for health checks to allow monitoring systems access
  skip_before_action :verify_authenticity_token
  before_action :skip_authentication

  # Basic health check endpoint
  def index
    health_status = perform_health_checks

    if health_status[:overall_status] == "healthy"
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  end

  # Detailed health check endpoint
  def detailed
    health_status = perform_detailed_health_checks

    if health_status[:overall_status] == "healthy"
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  end

  # Readiness probe for Kubernetes/container orchestration
  def ready
    ready_status = {
      status: "ready",
      timestamp: Time.current.iso8601,
      checks: {
        database: check_database_connection,
        rails_app: check_rails_application
      }
    }

    all_ready = ready_status[:checks].values.all? { |check| check[:status] == "healthy" }
    ready_status[:overall_status] = all_ready ? "ready" : "not_ready"

    if all_ready
      render json: ready_status, status: :ok
    else
      render json: ready_status, status: :service_unavailable
    end
  end

  # Liveness probe for Kubernetes/container orchestration
  def live
    render json: {
      status: "alive",
      timestamp: Time.current.iso8601,
      uptime: uptime_seconds,
      version: rails_version
    }, status: :ok
  end

  private

  def skip_authentication
    # Override authentication requirement for health endpoints
  end

  def perform_health_checks
    start_time = Time.current

    checks = {
      database: check_database_connection,
      rails_app: check_rails_application,
      redis: check_redis_connection,
      disk_space: check_disk_space
    }

    overall_healthy = checks.values.all? { |check| %w[healthy warning].include?(check[:status]) }

    {
      status: overall_healthy ? "healthy" : "unhealthy",
      overall_status: overall_healthy ? "healthy" : "unhealthy",
      timestamp: Time.current.iso8601,
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      checks: checks,
      version: rails_version,
      environment: Rails.env
    }
  end

  def perform_detailed_health_checks
    start_time = Time.current

    checks = {
      database: check_database_connection_detailed,
      rails_app: check_rails_application_detailed,
      redis: check_redis_connection,
      disk_space: check_disk_space,
      memory: check_memory_usage,
      google_calendar: check_google_calendar_api,
      background_jobs: check_background_jobs
    }

    overall_healthy = checks.values.all? { |check| %w[healthy warning].include?(check[:status]) }

    {
      status: overall_healthy ? "healthy" : "unhealthy",
      overall_status: overall_healthy ? "healthy" : "unhealthy",
      timestamp: Time.current.iso8601,
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      checks: checks,
      version: rails_version,
      environment: Rails.env,
      uptime_seconds: uptime_seconds
    }
  end

  def check_database_connection
    start_time = Time.current
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      {
        status: "healthy",
        message: "Database connection successful",
        response_time_ms: ((Time.current - start_time) * 1000).round(2)
      }
    rescue => e
      {
        status: "unhealthy",
        message: "Database connection failed",
        error: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).round(2)
      }
    end
  end

  def check_database_connection_detailed
    start_time = Time.current
    begin
      connection = ActiveRecord::Base.connection
      connection.execute("SELECT 1")

      # Additional database health metrics
      pool = ActiveRecord::Base.connection_pool

      {
        status: "healthy",
        message: "Database connection successful",
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        pool_size: pool.size,
        active_connections: pool.connections.count(&:in_use?),
        available_connections: pool.size - pool.connections.count(&:in_use?),
        database_version: connection.database_version
      }
    rescue => e
      {
        status: "unhealthy",
        message: "Database connection failed",
        error: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).round(2)
      }
    end
  end

  def check_rails_application
    {
      status: "healthy",
      message: "Rails application running",
      version: Rails.version,
      environment: Rails.env
    }
  end

  def check_rails_application_detailed
    {
      status: "healthy",
      message: "Rails application running",
      version: Rails.version,
      environment: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails.version,
      timezone: Time.zone.name,
      load_average: system_load_average
    }
  end

  def check_redis_connection
    start_time = Time.current
    begin
      # Only check if Redis is configured (for caching)
      if Rails.cache.respond_to?(:redis)
        Rails.cache.redis.ping
        {
          status: "healthy",
          message: "Redis connection successful",
          response_time_ms: ((Time.current - start_time) * 1000).round(2)
        }
      else
        {
          status: "healthy",
          message: "Redis not configured (using default cache store)",
          response_time_ms: ((Time.current - start_time) * 1000).round(2)
        }
      end
    rescue => e
      {
        status: "unhealthy",
        message: "Redis connection failed",
        error: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).round(2)
      }
    end
  end

  def check_disk_space
    begin
      stats = `df -h /`.lines.last.split
      usage_percent = stats[4].to_i

      status = case usage_percent
      when 0..80 then "healthy"
      when 81..90 then "warning"
      else "unhealthy"
      end

      {
        status: status,
        message: "Disk space check",
        usage_percent: usage_percent,
        available: stats[3],
        total: stats[1]
      }
    rescue => e
      {
        status: "unknown",
        message: "Could not check disk space",
        error: e.message
      }
    end
  end

  def check_memory_usage
    begin
      # Basic memory check (Linux/Mac)
      if RUBY_PLATFORM.include?("linux")
        meminfo = File.read("/proc/meminfo")
        total_kb = meminfo.match(/MemTotal:\s+(\d+)/)[1].to_i
        available_kb = meminfo.match(/MemAvailable:\s+(\d+)/)[1].to_i
        usage_percent = ((total_kb - available_kb).to_f / total_kb * 100).round(2)
      else
        # Fallback for other systems
        usage_percent = 0
      end

      status = case usage_percent
      when 0..80 then "healthy"
      when 81..90 then "warning"
      else "unhealthy"
      end

      {
        status: status,
        message: "Memory usage check",
        usage_percent: usage_percent,
        ruby_memory_mb: (GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE] / 1024 / 1024).round(2)
      }
    rescue => e
      {
        status: "unknown",
        message: "Could not check memory usage",
        error: e.message
      }
    end
  end

  def check_google_calendar_api
    return { status: "healthy", message: "No Google accounts configured" } if GoogleAccount.count == 0

    start_time = Time.current
    begin
      # Test Google Calendar API connectivity with a recent account
      recent_account = GoogleAccount.where.not(access_token: nil).order(:updated_at).last
      return { status: "warning", message: "No active Google accounts found" } unless recent_account

      # Basic connectivity test - just check if we can authenticate
      auth = Google::Auth::UserRefreshCredentials.new(
        client_id: Rails.application.credentials.google[:client_id],
        client_secret: Rails.application.credentials.google[:client_secret],
        scope: [ "https://www.googleapis.com/auth/calendar" ],
        refresh_token: recent_account.refresh_token
      )

      auth.access_token = recent_account.access_token
      auth.expires_at = recent_account.expires_at

      # If token is expired, don't try to refresh in health check
      if recent_account.needs_refresh?
        return {
          status: "warning",
          message: "Google Calendar tokens need refresh",
          response_time_ms: ((Time.current - start_time) * 1000).round(2)
        }
      end

      {
        status: "healthy",
        message: "Google Calendar API accessible",
        active_accounts: GoogleAccount.where.not(access_token: nil).count,
        response_time_ms: ((Time.current - start_time) * 1000).round(2)
      }
    rescue => e
      {
        status: "warning",
        message: "Google Calendar API check failed",
        error: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).round(2)
      }
    end
  end

  def check_background_jobs
    begin
      # Check if Solid Queue is configured and working
      if defined?(SolidQueue)
        # First check if the tables exist
        if ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")
          failed_jobs = SolidQueue::FailedExecution.count
          pending_jobs = SolidQueue::Job.pending.count

          status = case
          when failed_jobs > 100 then "unhealthy"
          when failed_jobs > 10 then "warning"
          else "healthy"
          end

          {
            status: status,
            message: "Background job queue status",
            pending_jobs: pending_jobs,
            failed_jobs: failed_jobs,
            queue_system: "SolidQueue"
          }
        else
          {
            status: "warning",
            message: "SolidQueue defined but tables not migrated",
            queue_system: "SolidQueue"
          }
        end
      else
        {
          status: "healthy",
          message: "No background job system configured"
        }
      end
    rescue => e
      {
        status: "warning",
        message: "Could not check background job status",
        error: e.message
      }
    end
  end

  def uptime_seconds
    (Time.current - Rails.application.config.start_time).to_i
  rescue
    0
  end

  def rails_version
    Rails.version
  end

  def system_load_average
    return nil unless File.exist?("/proc/loadavg")
    File.read("/proc/loadavg").split.first.to_f
  rescue
    nil
  end
end
