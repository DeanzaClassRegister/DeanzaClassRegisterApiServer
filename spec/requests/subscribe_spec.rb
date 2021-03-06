require 'rails_helper'

RSpec.describe 'Subscribe API', type: :request do
  let(:user) { create(:user) }
  let(:auth_token) { JsonWebToken.encode(user_id: user.id) }
  let(:header) { { 'Authorization' => auth_token } }
  let(:course) { create(:course, :with_lectures) }

  # todo: refactor duplicate tests
  describe 'POST /subscribe' do
    context 'subscribe when course is not subscribed' do
      before {
        post '/subscribe',
        params: {
          crn: course.crn,
          type: 'subscribe',
        },
        headers: header
      }

      it 'should responds 200' do
        expect(response).to have_http_status(200)
      end

      it 'should subscribe to all of the courses' do
        expect(user.subscribe_courses.length).to eq(1)
      end

      it 'response all the ids subscribed' do
        expect(json.length).to eq(1)
      end
    end

    context 'subscribe when course is already subscribed' do
      before { user.subscribe_courses << course }
      before {
        post(
          '/subscribe',
          params: {
            crn: course.crn,
            type: 'subscribe',
          },
          headers: header
        )
      }

      it 'should respond 200' do
         expect(response).to have_http_status(200)
       end

      it 'should unsubscribe' do
        expect(user.reload.subscribe_courses.length).to eq(0)
      end
    end

    context 'subscribe to courses that is liked or added to calendar' do
      before { user.calendar_courses << course }
      before {
        post(
          '/subscribe',
          params: {
            crn: course.crn,
            type: 'subscribe',
          },
          headers: header
        )
      }

      it 'should responds 200' do
        expect(response).to have_http_status(200)
      end

      it 'should subscribe to all of the courses' do
        expect(user.subscribe_courses.length).to eq(1)
      end
    end

    context 'like when course is not subscribed' do
      before {
        post '/subscribe',
        params: {
          crn: course.crn,
          type: 'like',
        },
        headers: header
      }

      it 'should responds 200' do
        expect(response).to have_http_status(200)
      end

      it 'should subscribe to all of the courses' do
        expect(user.like_courses.length).to eq(1)
      end

      it 'response all the ids subscribed' do
        expect(json.length).to eq(1)
      end
    end

    context 'like when course is already subscribed' do
      before { user.like_courses << course }
      before {
        post(
          '/subscribe',
          params: {
            crn: course.crn,
            type: 'like',
          },
          headers: header
        )
      }

      it 'should respond 200' do
         expect(response).to have_http_status(200)
       end

      it 'should unsubscribe' do
        expect(user.reload.like_courses.length).to eq(0)
      end
    end

    context 'add to calendar when course is not subscribed' do
      before {
        post '/subscribe',
        params: {
          crn: course.crn,
          type: 'calendar',
        },
        headers: header
      }

      it 'should responds 200' do
        expect(response).to have_http_status(200)
      end

      it 'should subscribe to all of the courses' do
        expect(user.calendar_courses.length).to eq(1)
      end

      it 'response all the ids subscribed' do
        expect(json.length).to eq(1)
      end
    end

    context 'add to calendar when course is already subscribed' do
      before { user.calendar_courses << course }
      before {
        post(
          '/subscribe',
          params: {
            crn: course.crn,
            type: 'calendar',
          },
          headers: header
        )
      }

      it 'should respond 200' do
         expect(response).to have_http_status(200)
       end

      it 'should unsubscribe' do
        expect(user.reload.calendar_courses.length).to eq(0)
      end
    end

    context 'when time conflicts' do
      before {
        user.calendar_courses << create(
          :course,
          :with_lectures,
          course: 'CIS 21JA'
        )
      }

      before {
        post(
          '/subscribe',
          params: {
            crn: course.crn,
            type: 'calendar',
          },
          headers: header
        )
      }

      it 'should respond 422' do
        expect(response).to have_http_status(422)
      end

      it 'should return an error message' do
        expect(json['message']).to match(/conflict/)
        expect(json['message']).to match(/CIS 21JA/)
      end
    end

    context 'when TBA lectures' do
      before { user.calendar_courses << create(:course, :with_tba_lectures) }
      before {
        post(
          '/subscribe',
          params: {
            crn: course.crn,
            type: 'calendar',
          },
          headers: header
        )
      }

      it 'should respond 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'contains calendar for different terms' do
      before {
        user.calendar_courses << create(
          :course, :with_lectures, quarter: '2016F'
        )
      }

      before {
        post(
          '/subscribe',
          params: {
            crn: course.crn,
            type: 'calendar',
          },
          headers: header
        )
      }

      it 'should respond 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'have course in a different day but same time' do
      it 'sould respond 200' do
        saved_course = create(:course, lectures: [create(:lecture, days: 'M······')])
        user.calendar_courses << saved_course
        intend_added_course = create(:course, lectures: [create(:lecture, days: '·T·····')])

        post(
          '/subscribe',
          params: {
            crn: intend_added_course.crn,
            type: 'calendar',
          },
          headers: header
        )

        expect(response).to have_http_status(200)
      end
    end
  end
end

