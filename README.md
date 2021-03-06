# Docdata
[![Build Status](https://secure.travis-ci.org/henkm/docdata.png)](http://travis-ci.org/henkm/docdata)
[![Gem Version](https://badge.fury.io/rb/docdata.svg)](http://badge.fury.io/rb/docdata)
[![Dependency Status](https://gemnasium.com/henkm/docdata.svg)](https://gemnasium.com/henkm/docdata)
[![Code Climate](https://codeclimate.com/github/henkm/docdata/badges/gpa.svg)](https://codeclimate.com/github/henkm/docdata)
[![Coverage Status](https://coveralls.io/repos/henkm/docdata/badge.png?branch=master)](https://coveralls.io/r/henkm/docdata)

Docdata is a Ruby implementation for using Docdata Payments.

Here you can find the [Documentation](http://rdoc.info/gems/docdata)

This gem relies on the awesome [Savon](http://savonrb.com/) gem to communicate with Docdata Payments' SOAP API.

## Installation

Add this line to your application's Gemfile:

    gem 'docdata'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install docdata

## Workflow
Each transaction consists of 2 - optionally 3 - parts:

- `Docdata::Shopper` (details about the shopper: name, email, etc.)
- `Docdata::Payment` (details about the payment: currency, gross amount, etc.) 
- `Docdata::LineItem` (optionally list the products of this payment) **currently not working!**


The general workflow is as follows:

1. Set up a `Docdata::Shopper` object with the details of your shopper: `@shopper = Docdata::Shopper.new` 
2. Set up a `Docdata::Payment` object with the details of your order: `@payment = Docdata::Payment.new(shopper: @shopper)`
3. Call the `create` method (`@payment.create`)
4. On success, store the payment key and use `@payment.redirect_url` to redirect the consumer to the transaction page.
5. When the consumer gets back to your application, use the `Docdata::Payment.find("PA1M3NTK3Y").status.paid` to check if the order was paid for.

## Parameters
All the payment details that Docdata Payments requires, are - obviously - also required to make payments via this gem.

#### Docdata::Shopper:
| Name | Type | Required | Defaults to |
|-----------|------------|---------|----|
| id | String (ID for own reference) | Yes | |
| first_name | String | Yes | First Name |
|	last_name | String | Yes | Last Name |
| street | String | Yes | Main Street |
| house_number | String | Yes | 123 |
| postal_code | String | Yes | 2244 |
| city | String | Yes | City |
| country_code | String (ISO country code) | Yes | NL |
| language_code | String (ISO language code) | Yes | nl |
| email | String | Yes | random@example.com |

#### Docdata::Payment:
| Name | Type | Required |
|-----------|------------|---------|
| amount | Integer (amount in cents) | Yes |
| currency | String (ISO currency code) | Yes |
| order_reference | String (your own unique reference) | Yes |
| description | String (max. 50 char.)| No |
| profile | String (name of your Docdata Payment profile)| Yes |
| shopper | Docdata::Shopper | Yes |
| line_items | Array (of Docdata::LineItem objects) | No |
| bank_id | String | No |
| prefered_payment_method | String | No |
| default_act | Boolean (should consumer skip docdata page?) | No |
| key | String (is available after successful 'create') | readonly |
| url | String (redirect URI is available after 'create') | readonly |


## Default values
A quick warning about the default values for the Shopper object: **For some payment methods, Docdata Payments needs the actual information in order for the payment to take place.**

If you use `GIROPAY`, `SEPA` and `AFTERPAY` this is the case. (Maybe also in other payment methods, please let me know!)


## Configuration in Rails application
Example usage. Use appropriate settings in `development.rb`, `production.rb` etc. 
```ruby
config.docdata.username   = "my_app_com"
config.docdata.password   = "HeJ35N"
config.docdata.return_url = "http://localhost:3000/docdata" # gets appended by '/success', '/error', '/pending' depending on response
config.docdata.test_mode  = true
```

## Example usage in Rails application
The example below assumes you have your application set up with a Order model, which contains the information needed for this transaction (amount, name, etc.).

```ruby

def start_transaction
	# find the order from your database
	@order = Order.find(params[:id])
	
	# initialize a shopper, use details from your order
	shopper = Docdata::Shopper.new(first_name: @order.first_name, last_name: @order.last_name)

	# set up a payment
	@payment = Docdata::Payment.new(
		amount: @order.total, 
		currency: @order.currency, 
		shopper: shopper,
		profile: "My Default Profile",
		order_reference: "order ##{@order.id}"
	)
	
	# create the payment via the docdata api and collect the result
	result = @payment.create

	if result.success?
		# Set the transaction key for future reference
		@order.update_column :docdata_key, result.key
		# redirect the user to the docdata payment page
		redirect_to @payment.redirect_url
	else
		# TODO: Display the error and warn the user that something went wrong.
	end
end

```

After a payment is completed, Docdata Payments will do two things:

1. Sends a GET request to your 'Update URL' (you can set this in the back office) with an 'id' parameter, containing your order_reference. This allows you to check the status of the transaction, before the user gets redirected back to your website.
2. Redirects the consumer back to the `return_url`.

```ruby
def check_transaction
	# find the order from your database
  # https://www.example.com/docdata/update?id=12345
	@order = Order.find_by_order_reference(params[:id])

	# Find this payment via the Docdata API,
	# using the previously set 'docdata_key' attribute.
  payment = Docdata::Payment.find(@order.docdata_key)
  response = payment.status
  if response.paid
    # use your own methods to handle a paid order
    # for example:
    @order.mark_as_paid(response.payment_method)
  else
  	# TODO: create logic to handle failed payments
  end

  # This action doesn't need a view template. It only needs to have a status 200 (OK)
	render :nothing => true, :status => 200, :content_type => 'text/html'
end

```

## Ideal

For transactions in the Netherlands, iDeal is the most common option. To redirect a user directly to the bank page (skipping the Docdata web menu page), you can ask your user to choose a bank from any of the banks listed in the `Docdata::Ideal.banks` method.

In `Docdata::Payment` you can set `bank_id` to any value. If you do, the redirect URI will redirect your user directly to the bank page.

Example code:

```ruby

def ideal_checkout
	@order = Order.find(params[:order_id])
	@banks = Docdata::Ideal.banks
end

def start_ideal_transaction
	@order = Order.find(params[:order_id])

	# initialize a shopper, use details from your order
	shopper = Docdata::Shopper.new(first_name: @order.first_name, last_name: @order.last_name)

	# set up a payment
	@payment = Docdata::Payment.new(
		amount: @order.total, 
		currency: @order.currency, 
		shopper: shopper,
		profile: "My Default Profile",
		order_reference: "order ##{@order.id}",
		bank_id: params[:bank_id],
		default_act: true # redirect directly to the bank, skipping the Docdata web menu
	)

	# create the payment via the docdata api and collect the result
	result = @payment.create

	if result.success?
		# Set the transaction key for future reference
		@order.update_column :docdata_key, result.key
		# redirect the user to the bank page
		redirect_to @payment.redirect_url
	else
		# TODO: Display the error and warn the user that something went wrong.
	end
end

```

View template (ideal_checkout.html.erb):

```html

<h2>Choose your bank</h2>
<%= form_tag start_ideal_transaction_path, method: :post, target: "_blank" do %>
<%= select_tag "bank_id", options_from_collection_for_select(@banks, "id", "name") %>
<%= hidden_field_tag :order_id, @order.id %>
<%= submit_tag "Proceed to checkout" %>
<% end %>

```

## Tips and samples

#### Redirect directly to bank page (skip Docdata web menu)
When making a new `Docdata::Payment`, use the `default_act` parameter to redirect consumers directly to the acquirers website. Example:

```ruby

@payment = Docdata::Payment.new(
	amount: @order.total, 
	currency: @order.currency, 
	shopper: shopper,
	profile: "My Default Profile",
	order_reference: "order ##{@order.id}",
	bank_id: params[:bank_id],
	default_act: true # redirect directly to the bank, skipping the Docdata web menu
)

```

#### Retrieve a list of iDeal banks to show
`Docata::Ideal.banks` returns an Array.

#### Find a payment
`Docdata::Payment.find("PAYMENTORDERKEYHERE")` returns either a `Docdata::Payment` object or a 'not found' error.

#### Check the status of a payment
`payment = Docdata::Payment.find("KEY"); payment.status => <Payment::Status>`

#### Cancel a payment
To cancel an existing Payment, you can do one of the following:
`payment = Docdata::Payment.find("KEY"); payment.cancel` or `Docdata::Payment.cancel("KEY")`

#### Make refunds
You can make a refund for a payment. In fact: each payment can have multiple refunds. Each refund has an amount (`Integer` type - cents) and as long as the refund amount doesn't exceed the total Payment amount, you can make as many partial refunds as you whish. Keep in mind that Docdata will charge you for each refund.

```ruby
payment = Docdata::Payment.find("KEY") # find the payment
payment.refund(500) # => true or false
```



## Test credentials
In order tot test this gem, you'll need to set the following environment variables to make it work. With other words: you can't test this gem without valid test credentials and you can't use my test credentials. Tip: set the environment variables in your .bash_profile file.
```
ENV["DOCDATA_PASSWORD"] = "your_password"
ENV["DOCDATA_USERNAME"] = "your_docdata_username"
ENV["DOCDATA_RETURN_URL"] = "http://return-url-here"
```    


## Contributing
Want to contribute? Great!

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Make changes, document them and add tests (rspec)
4. Run the entire test suite and make sure all tests pass (`rake`)
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create new Pull Request
