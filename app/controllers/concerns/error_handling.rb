module ErrorHandling
  module HttpStatusCodes
    def not_found
      render status: 404
    end

    def bad_request
      render status: 400
    end
  end
end

