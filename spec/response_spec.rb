require 'spec_helper'

describe Docdata::Response do
  context ":status, new unpaid payment" do
    before(:each) do
      file = "#{File.dirname(__FILE__)}/xml/status-new.xml"
      @xml = open(file)
      @response = Docdata::Response.parse(:status, @xml)
    end

    it "is not paid" do
      expect(@response).to be_success
    end
  end

  context ":status, paid iDeal" do
    before(:each) do
      file = "#{File.dirname(__FILE__)}/xml/status-paid-ideal.xml"
      @xml = open(file)
      @response = Docdata::Response.parse(:status, @xml)
    end

    it "has 'total_registered' method" do
      expect(@response.total_registered).to eq(500)
    end

    it "returns 0 for empty values" do
      expect(@response.total_shopper_pending).to eq(0)
    end

    it "returns amount" do
      expect(@response.amount).to eq(500)
    end

    it "returns payment_method" do
      expect(@response.payment_method).to eq("IDEAL")
    end

    it "is paid" do
      expect(@response).to be_success
      expect(@response).to be_paid
    end

    it "is NOT canceled" do
      expect(@response).to be_success
      expect(@response).not_to be_canceled
    end

  end

  context ":status, canceled iDeal" do
    before(:each) do
      file = "#{File.dirname(__FILE__)}/xml/status-canceled-ideal.xml"
      @xml = open(file)
      @response = Docdata::Response.parse(:status, @xml)
    end

    it "has 'total_registered' method" do
      expect(@response.total_registered).to eq(500)
    end

    it "returns 0 for empty values" do
      expect(@response.total_shopper_pending).to eq(0)
    end

    it "returns amount" do
      # puts "xml: #{@response.xml}"
      expect(@response.amount).to eq(500)
    end

    it "returns payment_method" do
      expect(@response.payment_method).to eq("IDEAL")
    end

    it "is NOT paid" do
      expect(@response).to be_success
      expect(@response).not_to be_paid
    end

    it "is canceled" do
      expect(@response).to be_success
      expect(@response).to be_canceled
    end    

  end

  context ":status, paid creditcard" do
    before(:each) do
      file = "#{File.dirname(__FILE__)}/xml/status-paid-creditcard.xml"
      @xml = open(file)
      @response = Docdata::Response.parse(:status, @xml)
    end

    it "has 'total_registered' method" do
      expect(@response.total_registered).to eq(500)
    end

    it "returns amount" do
      expect(@response.amount).to eq(500)
    end

    it "returns payment_method" do
      expect(@response.payment_method).to eq("MASTERCARD")
    end

    it "is paid" do
      expect(@response).to be_success
      expect(@response).to be_paid
    end

    it "is NOT canceled" do
      expect(@response).to be_success
      expect(@response).not_to be_canceled
    end

  end

  context ":status, canceled creditcard" do
    before(:each) do
      file = "#{File.dirname(__FILE__)}/xml/status-canceled-creditcard.xml"
      @xml = open(file)
      @response = Docdata::Response.parse(:status, @xml)
    end

    it "returns amount" do
      expect(@response.amount).to eq(500)
    end

    it "is NOT paid" do
      expect(@response).to be_success
      expect(@response).not_to be_paid
    end

    it "is canceled" do
      expect(@response).to be_success
      expect(@response).to be_canceled
    end    

  end  

end