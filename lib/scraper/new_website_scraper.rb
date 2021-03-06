class DeAnzaScraper
  class NewWebsiteScraper
    def scrape(quarter)
      get_courses(department_list, quarter)
    end

    def get_course(crn, quarter)
      html = get_parsed_html course_detail_url(crn, quarter)

      # handle course not found
      return nil if html.css('h2').first.text == 'Ooops...'

      trs = html.css('.table-schedule tbody tr')
      first_row = trs[0].css('td')
      if trs[1]
        second_row = trs[1].css('td')
      end

      course = {
        crn: crn,
        course: html.css('small').first.text,
        department: html.css('small').first.text.split(' ')[0],
        quarter: quarter,
        description: html.css('h3 + p').first.text,
        class_material: html.css('.table-schedule + p a').first.attr('href'),
        prerequisites_note: '',
        prerequisites_advisory: '',

        'lectures_attributes' => [{
            title:      html.css('h2')[0].text,
            days:       first_row[3].text,
            times:      first_row[4].text,
            instructor: first_row[5].text,
            location:   first_row[6].text,
        }],
      }

      if second_row
        course['lectures_attributes'].push({
          title:      'LAB',
          days:       second_row[0].text,
          times:      second_row[1].text,
          instructor: second_row[2].text,
          location:   second_row[3].text,
        })
      end

      dt_tags = html.css('h3 + dl dt').each do |dt|
        course[:prerequisites_note] = dt.next_element.try(:text) if dt.text == 'Note'
        course[:prerequisites_advisory] = dt.next_element.try(:text) if dt.text == 'Advisory'
      end

      course
    end

    def get_courses_status(quarter)
      courses = Array.new

      department_list.each do |department|
        html = get_parsed_html course_list_url(department, quarter)
        table_rows = html.css(".table-schedule tbody tr.mix")

        # there might be some case where nothing is found
        next if table_rows.empty?

        current_row = 0
        while current_row < table_rows.count
          tds = table_rows[current_row].css('td')

          course = {
            crn: tds[0].text,
            status: tds[3].text,
          }

          course[:status] = 'Waitlist' if course[:status] == 'WL'

          courses.push course

          # skip through class with more than one lectures
          current_row += numberOfExtraLectures(table_rows[current_row])
          current_row += 1
        end
      end

      courses
    end

    private
    def department_list
      html = get_parsed_html 'https://www.deanza.edu/schedule/'

      dept_options = html.css('#dept-select option')
      dept_options = dept_options.map { |option| option.attr('value') }

      # the first option is just the prompt
      dept_options.shift

      dept_options
    end

    def get_courses(dept_options, quarter)
      progressbar = ProgressBar.create(
        title: 'Grabbing courses from deanza.edu',
        total: dept_options.count,
        format: '%t: |%B%p%|'
      )

      courses = Array.new

      dept_options.each do |department|
        # increment progressbar
        progressbar.increment

        html = get_parsed_html course_list_url(department, quarter)

        # get the table of courses
        table_rows = html.css(".table-schedule tbody tr.mix")

        # there might be some case where nothing is found
        next if table_rows.empty?

        courses.concat extract_course_data(table_rows, quarter, department)
      end

      progressbar.finish

      progressbar = ProgressBar.create(
        title: 'Getting detail data of every course',
        total: courses.count,
        format: '%t: |%B%p%|'
      )

      courses.each do |course|
        # increment progressbar
        progressbar.increment

        html = get_parsed_html course_detail_url(course[:crn], quarter)

        dt_tags = html.css('h3 + dl dt').each do |dt|
          course[:prerequisites_note] = dt.next_element.try(:text) if dt.text == 'Note'
          course[:prerequisites_advisory] = dt.next_element.try(:text) if dt.text == 'Advisory'
        end

        course[:description] = html.css('h3 + p').first.text
        course[:class_material] = html.css('.table-schedule + p a').first.attr('href')
      end

      progressbar.finish

      courses
    end

    def get_parsed_html(url)
      Nokogiri::HTML.parse(RestClient.get(url))
    end

    def course_list_url(department, quarter)
      "https://www.deanza.edu/schedule/listings.html?dept=#{department}&t=#{quarter}"
    end

    def course_detail_url(crn, quarter)
      "https://deanza.edu/schedule/class-details.html?crn=#{crn}&y=#{quarter[1..4]}&q=#{quarter[0]}"
    end

    def numberOfExtraLectures(row)
      rowspan = row.css('td').first.attr('rowspan').to_i
      rowspan == 0 ? 0 : rowspan - 1
    end

    def extract_lecture_data(row)
      tds = row.css('td')

      {
        title:      tds[0].children.first.text,
        days:       tds[1].text,
        times:      tds[2].text,
        instructor: tds[3].children.text,
        location:   tds[4].text
      }
    end

    def extract_course_data(table_rows, quarter, department)
      courses = Array.new

      current_row = 0
      while current_row < table_rows.count
        tds = table_rows[current_row].css('td')

        course = {
          crn:        tds[0].text,
          course:     tds[1].text,
          status:     tds[3].text,
          department: department,
          quarter: quarter,
          description: '',
          class_material: '',
          prerequisites_note: '',
          prerequisites_advisory: '',

          'lectures_attributes' => [{
            title:      tds[4].children.first.text,
            days:       tds[5].text,
            times:      tds[6].text,
            instructor: tds[7].children.text,
            location:   tds[8].text
          }]
        }

        course[:status] = 'Waitlist' if course[:status] == 'WL'

        # if it has more than one lectures
        # get lecture data from the next n rows
        numberOfExtraLectures(table_rows[current_row]).times do |num|
          course['lectures_attributes'].push extract_lecture_data(table_rows[current_row + 1])
          current_row += 1
        end

        courses.push course
        current_row += 1
      end

      courses
    end
  end
end
