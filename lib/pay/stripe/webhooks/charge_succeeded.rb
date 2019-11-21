module Pay
  module Stripe
    module Webhooks

      class ChargeSucceeded
        def call(event)
          object = event.data.object
          user   = Pay.user_model.find_by(
            processor: :stripe,
            processor_id: object.customer
          )

          return unless user.present?
          return if user.charges.where(processor_id: object.id).any?

          charge = create_charge(user, object)
          notify_user(user, charge)
          charge
        end

        def create_charge(user, object)
          charge = user.charges.find_or_initialize_by(
            processor:      :stripe,
            processor_id:   object.id,
          )
          if object.source.nil?
            card = object.payment_method_details.card
          else
            card = object.source
          end
          charge.update(
            amount:         object.amount,
            card_last4:     card.last4,
            card_type:      card.brand,
            card_exp_month: card.exp_month,
            card_exp_year:  card.exp_year,
            created_at:     DateTime.now
          )

          charge
        end

        def notify_user(user, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.receipt(user, charge).deliver_later
          end
        end
      end
    end
  end
end