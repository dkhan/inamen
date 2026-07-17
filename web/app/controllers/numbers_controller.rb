# frozen_string_literal: true

class NumbersController < ApplicationController
  def index
    value = params[:number].to_s.delete(",").strip
    if value.present?
      redirect_to number_path(value)
      return
    end

    @examples = [7, 49, 77, 153, 343, 490, 777, 980, 1029]
  end

  def show
    @number = params[:id].to_s.delete(",").strip
    unless @number.match?(/\A[1-9]\d*\z/)
      redirect_to numbers_path, alert: "Enter a positive whole number."
      return
    end

    @facts = Inamen::NumberFacts.build(@number)
  rescue ArgumentError
    redirect_to numbers_path, alert: "Enter a positive whole number."
  end
end
