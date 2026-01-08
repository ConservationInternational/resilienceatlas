module Api
  module V1
    class FeedbacksController < ApiController
      def create
        feedback = Feedback.new feedback_params
        if feedback.save
          render json: feedback, include: [feedback_fields: :children]
        else
          render json: {errors: feedback.errors}, status: :unprocessable_entity
        end
      end

      private

      def feedback_params
        params.require(:feedback).permit :language,
          feedback_fields_attributes: [
            :feedback_field_type,
            :question,
            answer: {},
            children_attributes: [
              :feedback_field_type,
              :question,
              answer: {}
            ]
          ]
      end
    end
  end
end
