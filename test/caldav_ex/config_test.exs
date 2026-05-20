defmodule CalDAVEx.ConfigTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.Config

  test "creates config with base_url and auth" do
    config = Config.new("https://caldav.example.com", :no_auth)
    
    assert config.base_url == "https://caldav.example.com"
    assert config.auth == :no_auth
    assert config.user_agent == "caldav_ex/0.1.0"
    assert config.timeout_ms == 10_000
  end

  test "strips trailing slash from base_url" do
    config = Config.new("https://caldav.example.com/", :no_auth)
    
    assert config.base_url == "https://caldav.example.com"
  end

  test "with_user_agent updates user agent" do
    config = 
      Config.new("https://caldav.example.com", :no_auth)
      |> Config.with_user_agent("MyApp/1.0")
    
    assert config.user_agent == "MyApp/1.0"
  end

  test "with_timeout updates timeout" do
    config = 
      Config.new("https://caldav.example.com", :no_auth)
      |> Config.with_timeout(30_000)
    
    assert config.timeout_ms == 30_000
  end

  test "config can be chained" do
    config = 
      Config.new("https://caldav.example.com/", {:basic, "user", "pass"})
      |> Config.with_user_agent("CustomClient/2.0")
      |> Config.with_timeout(60_000)
    
    assert config.base_url == "https://caldav.example.com"
    assert config.auth == {:basic, "user", "pass"}
    assert config.user_agent == "CustomClient/2.0"
    assert config.timeout_ms == 60_000
  end
end
