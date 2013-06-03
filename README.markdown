# Messy Controller Refactoring

### Goal

Take a walk with me as I refactor a really ugly controller from one of my previous projects. 

### Project Background

The following code sample is from a gSchool project called Daughter of Store Engine (DOSE). The project involved taking legacy code (actually code from a previous ecommerce project we built just weeks prior) and turning it into a multi-tenant auction platform that owners of online stores could use to offload excess merchandise. Think Shopify for eBay!

### Business Requirement

In order to reduce fraud and fake bids, our client (our instructors) mandated that users have a valid credit card on file before being allowed to submit a bid. If a bidder was logged in and didn't have a valid credit card on file, they would be provided with a notification containing a link to their profile, where they could add a credit card to their profile (verified by Stripe). If the bidder were to successfully add a credit card at that point in time, they would then be redirected to the bid page where they left off with their previously entered bid saved in the form ready to be submitted. The key here was to provide a seamless experience so users could quickly get back to bidding and our fictitious merchants could rake in all that fictitious cash!

### Bids Controller

Since the requirement involved users submitting bids, I decided that the create method in the Bids Controller would be the place where all of the action happened. Here's what I initially came up with:


```
class BidsController < ApplicationController

  #  Other code omitted

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

```

##### What was I thinking?

I'll be the first to admit, this isn't pretty. There's way too much going on in the create method. This totally ignores the Single Responsibility Principle and breaks plenty of other rules. To be fair, I knew it was pretty bad when I wrote it, but we were under some time constraints and I felt shipping well-tested ugly code was much better than not shipping at all.

##### It's Refactor Time!

Since, I'm several weeks older and wiser since writing this code, it's high time that I make this controller look presentable. 

The first thing that jumps out at me is that there is way too much logic being forced into the create method. First, the code checks if you're a current user, then I check if you have a valid credit card on file. Only after all of that, do I get to the real job of the create method - which is to actually create a new bid.

While I feel that these checks need to happen and that the create method is the place in the code where they should occur, there's definitely a better way to organize the code to make it readable and amenable to change.

##### Embedded If-Statements suck!

Embedded If-statements used to be my best friend, but we had a falling out since I started gSchool. Let's get rid of them.

The `if current_user` line checks if the person submitting the bid is actually logged in. It meets our client's requirement, but sticking all of the logic associated with the user not being logged in seems out of place.

I've learned that sometimes it's best to ask yourself a simple question - "what is really happening here?"  Well, what we're really doing is making sure we prevent bidders who are not currently logged in from submitting a bid. The next question I ask myself is "does that logic or idea belong in the create method?"  It's clear that the answer is no, so let's move it out into it's own method:

```
  def no_bid_allowed
    save_bid_data_in_session
    flash[:alert] = "You must log in to bid."
    redirect_to login_path
    return
  end

```

Here my goal is to provide a verbose method name so the purpose of this method is crystal clear. 

Back in the create method, we would add something like this to complete our check for a logged in user:

```
no_bid_allowed unless current_user
```

With those two moves, we can now remove the outer if-statement:

```
  def create
    clear_bid_session_data

    no_bid_allowed unless current user

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

  end
```

That's a step in the right direction but there's still work to be done. Let's focus our attention on the code that checks for a valid credit card:

`if current_user.valid_credit_card?`

Once again, I think the create method is the place where this check should be made however, the associated logic that goes along with an invalid credit card belongs somewhere else. Let's move it out of there:

```
  def no_valid_credit_card_on_file
    save_bid_data_in_session
    flash[:notice] = credit_card_notification
    @auction = Auction.find(params[:auction_id])
    @bid = Bid.new
    render 'auctions/show'
    return
  end

  def credit_card_notification
    "Oops, a valid credit card is required before you can submit a bid.
     Click here to add a credit card to your account:
    #{self.class.helpers.link_to( 'Edit Your Account', edit_profile_path) }".html_safe
  end
```

Here I extracted all of that misplaced logic and place it into its own method with a name that makes the method's purpose obvious. 

Back in the create method, I can now replace the if-statement with:

```
no_valid_credit_card_on_file unless current_user.valid_credit_card?
```

With that move, I'm able to remove the other if-statement, which leaves our create method doing the one job it's great at - creating a bid:

```
  def create
    clear_bid_session_data

    no_bid_allowed unless current_user
    no_valid_credit_card_on_file unless current_user.valid_credit_card?

    @bid = Bid.new(amount: params[:bid][:amount], auction_id: params[:auction_id],
                   user_id: current_user.id)
    @bid.save ? notice_message : alert_message
  end
```

### The Aftermath

Here's what the newly refactored create method looks like:

```
class BidsController < ApplicationController

  #Other code omitted

  def create
    clear_bid_session_data

    no_bid_allowed unless current_user
    no_valid_credit_card_on_file unless current_user.valid_credit_card?

    @bid = Bid.new(amount: params[:bid][:amount], auction_id: params[:auction_id],
                   user_id: current_user.id)
    @bid.save ? notice_message : alert_message
  end

  private

  def no_bid_allowed
    save_bid_data_in_session
    flash[:alert] = "You must log in to bid."
    redirect_to login_path
    return
  end

  def no_valid_credit_card_on_file
    save_bid_data_in_session
    flash[:notice] = credit_card_notification
    @auction = Auction.find(params[:auction_id])
    @bid = Bid.new
    render 'auctions/show'
    return
  end

  def credit_card_notification
    "Oops, a valid credit card is required before you can submit a bid.
     Click here to add a credit card to your account:
    #{self.class.helpers.link_to( 'Edit Your Account', edit_profile_path) }".html_safe
  end

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

```

There you have it. I'm sure the code still has a lot of room for improvement, but it's definitely a step up from my original implementation. 
