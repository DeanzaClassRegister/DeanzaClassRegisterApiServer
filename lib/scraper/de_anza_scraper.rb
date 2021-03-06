require_relative './new_website_scraper'
require_relative './myportal_scraper'

class DeAnzaScraper
  def self.create_course
    # get course data from www.deanza.edu
    update_course_with_scraper('Updating database') do
      DeAnzaScraper::NewWebsiteScraper.new.scrape(quarter)
    end
  end

  def self.update_status
    if Course.where(quarter: quarter).any?
      course_data = DeAnzaScraper::NewWebsiteScraper.new.get_courses_status(quarter)
      self.update_database(course_data)
    else
      self.create_course
    end
  end

  def self.update_course_with_scraper(title)
    course_data = yield

    # setup progressbar
    progressbar = ProgressBar.create(
      title: title,
      total: course_data.count,
      format: '%t: |%B%p%|'
    )

    # update course in the database
    Course.transaction do
      course_data.each do |data|
        progressbar.increment

        if course = Course.find_by(crn: data[:crn], quarter: quarter)

          if data['lectures_attributes'].present?
            data['lectures_attributes'].each do |lecture|
              lecture[:id] = course.lectures.find_by(title: lecture[:title]).try(:id)
            end
          end

          course.update(data)
        else
          # todo: this will never happen because course.course is required
          # need another scraper to update a specific course from deanza.edu
          Course.create(data)
        end
      end
    end

    # end progressbar and print finish prompt
    progressbar.finish
  end

  def self.update_database(course_data)
    db_course_data = Course.where(quarter: quarter).select(
      :id, :crn, :course, :status,
    ).to_a

    Course.transaction do
      course_data.each do |data|
        if index = db_course_data.find_index { |course| course.crn == data[:crn] }
          course = db_course_data.delete_at(index)
          if course.status != data[:status]
            course.notification_subscribers.each do |user|
              user.course_status_update_notifications.create(
                message: "The class #{course.course} that you've subscribed to has changed its status from #{course.status} to #{data[:status]}",
                course_id: course.id
              )

              UserMailer.notify_status_change(user, course, course.status, data[:status]).deliver_later!
            end

            # use update_columns to skip callbacks
            # in this case, the flush_cache callback
            course.update_columns(data)
          end
        else
          # create the course here
          # get the full course data first
          course = DeAnzaScraper::NewWebsiteScraper.new.get_course(data[:crn], quarter)

          if course
            course.merge!(data)
            Course.create(course)
          end
        end
      end
    end

    # sometime after the quarter, some course will disappear on
    # the list. in order not to delete most of the course
    # check here if there are at least 1000 courses
    if db_course_data.any? && course_data.length > 1000
      Course.transaction do
        db_course_data.each do |course|
          course.destroy
        end
      end
    end

    # clear the cache all at once
    Rails.cache.clear
  end

  private

  def self.quarter
    Rails.application.credentials.quarter
  end

  def self.termcode
    Rails.application.credentials.termcode
  end
end

