class BidsController < ApplicationController

  layout 'profile', only: [:index]
  before_filter :require_current_user, only: ['index']

  def index
    @bids = Bid.includes(auction: :product).find_all_by_user_id(current_user)
  end

  def create
    clear_bid_session_data

    if current_user
      if current_user.valid_credit_card?
        @bid = Bid.new(amount: params[:bid][:amount], auction_id: params[:auction_id],
                       user_id: current_user.id)
        @bid.save ? notice_message : alert_message
      else
        save_bid_data_in_session

        flash[:notice] = "Oops, a valid credit card is required before you can submit a bid.
                          Click here to add a credit card to your account:
                          #{self.class.helpers.link_to( 'Edit Your Account', edit_profile_path) }".html_safe

        @auction = Auction.find(params[:auction_id])
        @bid = Bid.new
        render 'auctions/show'
      end
    else
      save_bid_data_in_session
      flash[:alert] = "You must log in to bid."
      redirect_to login_path
    end

  end

  private

  def notice_message
    redirect_to auction_path(params[:auction_id]),
    notice: "You are currently the highest bidder!"
  end

  def alert_message
    redirect_to auction_path(params[:auction_id]),
    alert: 'Your bid must be higher than the current bid'
  end

  def save_bid_data_in_session
    session[:bid_data] = nil if session[:bid_data]
    session[:bid_data] = {amount: params[:bid][:amount],
                          auction_id: params[:auction_id]}
  end

  def clear_bid_session_data
    session[:bid_data] = nil if session[:bid_data]
  end

end
