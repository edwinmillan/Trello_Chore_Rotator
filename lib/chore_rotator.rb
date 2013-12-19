require 'rest-client'
require 'uri'
require 'json'

class ChoreRotator
  attr_accessor :api_key, :auth_token, :base_url, :template_id, :additional_members
  def initialize(opts = {})
    @base_url             = opts[:base_url]           || "https://api.trello.com/1"
    @auth_token           = opts[:auth_token]         || raise_arg_error(:auth_token)
    @api_key              = opts[:api_key]            || raise_arg_error(:api_key)
    @template_id          = opts[:template_id]        || raise_arg_error(:template_id)
    @additional_members   = opts[:additional_members] || false
  end

  def rotate_chores
    copied_board = copy_template_board
    add_members(copied_board) if additional_members
    copy_daily_cards(copied_board)
    archive_daily_list(copied_board)
    rename_lists(copied_board)
  end

  private

  def add_members(board)
    additional_members.map do |member|
      RestClient.put add_members_url({member: member, board: board}), false
    end
    return nil
  end

  def add_members_url(member_board)
    return URI.encode "#{base_url}/boards/#{member_board[:board]["id"]}/members/#{member_board[:member]}?key=#{api_key}&token=#{auth_token}&idMember=#{member_board[:member]}&type=normal"
  end

  def rename_lists(board)
    weekdays = board_lists(board["id"])
    date = Time.now
    weekdays.map do |list|
      RestClient.put rename_url( {list: list, date: date} ), false
      date += 86400
    end
    return nil
  end

  def rename_url(list_date)
    return URI.encode "#{base_url}/lists/#{list_date[:list]["id"]}?key=#{api_key}&token=#{auth_token}&name=#{list_date[:list]["name"]} #{list_date[:date].strftime("%m-%d-%y")}"
  end

  def archive_daily_list(board)
    daily_list = board_lists(board["id"]).first
    response = RestClient.put archive_list_url(daily_list), false
    return nil
  end

  def archive_list_url(daily_list)
    return URI.encode "#{base_url}/lists/#{daily_list["id"]}?key=#{api_key}&token=#{auth_token}&closed=true"
  end

  def copy_daily_cards(board)
    raw_lists = board_lists(board["id"])
    daily = raw_lists[0]
    weekdays = raw_lists.slice(1..-1)

    weekdays.map do |list|
      listed_cards(daily["id"]).map do |card|
        copy_card( {list: list, card: card} )
      end
    end
    return nil
  end

  def copy_card(card_and_list)
    response = RestClient.post copy_card_url(card_and_list), false
    return JSON.parse response
  end

  def copy_card_url(card_and_list)
    return URI.encode "#{base_url}/cards?key=#{api_key}&token=#{auth_token}&name=#{card_and_list[:card]["name"]}&idCardSource=#{card_and_list[:card]["id"]}&idList=#{card_and_list[:list]["id"]}"
  end

  def listed_cards(list_id)
    response = RestClient.get listed_cards_url(list_id)
    return JSON.parse response
  end

  def listed_cards_url(list_id)
    return URI.encode "#{base_url}/lists/#{list_id}/cards?key=#{api_key}&token=#{auth_token}"
  end

  def board_lists(board_id)
    response = RestClient.get board_lists_url(board_id)
    return JSON.parse response
  end

  def board_lists_url(board_id)
    return URI.encode "#{base_url}/boards/#{board_id}/lists?key=#{api_key}&token=#{auth_token}"
  end

  def copy_template_board
    response = RestClient.post copy_template_board_url, false
    return JSON.parse response
  end

  def copy_template_board_url
    new_board_name = "Chores for the Week of #{Time.now.strftime("%m-%d-%y")}"
    return URI.encode "#{base_url}/boards?key=#{api_key}&token=#{auth_token}&name=#{new_board_name}&idBoardSource=#{template_id}"
  end

  def list_boards
    response = RestClient.get list_boards_url
    return JSON.parse response
  end

  def list_boards_url
    return URI.encode "#{base_url}/members/me/boards?key=#{api_key}&token=#{auth_token}&fields=name&filter=open"
  end

  def raise_arg_error(arg)
    raise ArgumentError, "You must include a #{arg.inspect} option when calling ChoreRotator.new"
  end

end