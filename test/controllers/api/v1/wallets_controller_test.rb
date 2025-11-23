require "test_helper"

class Api::V1::WalletsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get api_v1_wallets_show_url
    assert_response :success
  end
end
