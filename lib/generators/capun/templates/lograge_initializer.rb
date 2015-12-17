require "active_support/notifications/instrumenter"

class ActiveSupport::Notifications::Instrumenter

  alias_method :instrument_original, :instrument

  def instrument(name, payload = {})
    instrument_original(name, payload) do
      begin
        yield
      rescue Exception => e
        payload[:stacktrace] = e.backtrace
        raise
      end
    end
  end
end