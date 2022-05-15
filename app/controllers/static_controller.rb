class StaticController < ApplicationController
  def faq
    respond_to do |format|
      format.html { render :faq }
    end
  end

  def about
    respond_to do |format|
      format.html { render :about }
    end
  end
end
