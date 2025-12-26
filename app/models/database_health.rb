# Model for database health checks and connection pool monitoring
class DatabaseHealth
  def self.connection_metrics
    connection = ActiveRecord::Base.connection
    pool = ActiveRecord::Base.connection_pool
    pool_size = pool.size
    active_connections = pool.connections.count(&:in_use?)

    {
      pool_size: pool_size,
      active_connections: active_connections,
      available_connections: pool_size - active_connections,
      database_version: connection.database_version
    }
  end

  def self.check_connection
    start_time = Time.current
    begin
      connection = ActiveRecord::Base.connection
      connection.execute("SELECT 1")

      {
        status: "healthy",
        message: "Database connection successful",
        response_time_ms: calculate_response_time(start_time),
        **connection_metrics
      }
    rescue => e
      {
        status: "unhealthy",
        message: "Database connection failed",
        error: e.message,
        response_time_ms: calculate_response_time(start_time)
      }
    end
  end

  private

  def self.calculate_response_time(start_time)
    ((Time.current - start_time) * 1000).round(2)
  end
end
