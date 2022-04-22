require "test_helper"

class PasswordResetsTest < ActionDispatch::IntegrationTest

  def setup
    ActionMailer::Base.deliveries.clear
    @user = users(:diego)
  end

  test "should not send password reset with invalid email" do
    get new_password_reset_path
    assert_template 'password_resets/new'
    assert_select 'input[name=?]', 'password_reset[email]'
    # Invalid email
    post password_resets_path, params: { password_reset: { email: "" }}
    assert_not flash.empty?
    assert_template 'password_resets/new'
  end

  test "should send password reset with valid email" do
    get new_password_reset_path
    assert_template 'password_resets/new'
    assert_select 'input[name=?]', 'password_reset[email]'
    # Valid email
    post password_resets_path, params: { password_reset: { email: @user.email }}
    assert_not_equal @user.reset_digest, @user.reload.reset_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url
  end

  test "should not be able to edit password with invalid email on the reset link" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    get edit_password_reset_path(user.reset_token, email: "")
    assert_redirected_to root_url
  end


  test "should not be able to edit password as inactive user" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    user.toggle!(:activated)
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_redirected_to root_url
  end

  test "should not be able to edit password with invalid reset token" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    get edit_password_reset_path('invalid-token', email: user.email)
    assert_redirected_to root_url
  end

  test "should be able to display the edit password when valid token and email provided" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_template 'password_resets/edit'
    assert_select "input[name=email][type=hidden][value=?]", user.email
  end

  test "should not be able to change password when not matching passwords provided" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    get edit_password_reset_path(user.reset_token, email: user.email)
    patch password_reset_path(user.reset_token), params: {email: user.email,
                                                          user: {
                                                            password: "password1",
                                                            password_confirmation: "password2"
                                                          }}
    assert_select 'div#error_explanation'
  end

  test "should not be able to change password when empty passwords provided" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    get edit_password_reset_path(user.reset_token, email: user.email)
    patch password_reset_path(user.reset_token), params: {email: user.email,
                                                          user: {
                                                            password: "",
                                                            password_confirmation: ""
                                                          }}
    assert_select 'div#error_explanation'
  end

  test "should be able to change password when valid passwords provided" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    get edit_password_reset_path(user.reset_token, email: user.email)
    patch password_reset_path(user.reset_token), params: {email: user.email,
                                                          user: {
                                                            password: "password",
                                                            password_confirmation: "password"
                                                          }}
    assert is_logged_in?
    assert_not flash.empty?
    assert_redirected_to user
    user.reload
    assert_nil user.reset_digest
  end

  test "should not be able to change password when the reset token expires" do
    post password_resets_path, params: { password_reset: { email: @user.email }}
    user = assigns(:user)
    user.update_attribute(:reset_sent_at, 3.hours.ago)
    get edit_password_reset_path(user.reset_token, email: user.email)
    patch password_reset_path(user.reset_token), params: {email: user.email,
                                                          user: {
                                                            password: "password",
                                                            password_confirmation: "password"
                                                          }}
    assert_response :redirect
    follow_redirect!
    assert_match 'expired', response.body
  end

end
