class Scheduler
  def self.create_resume_event_on_read(fiber : Fiber, fd : Int)
    @@eb.new_event(fd, LibEvent2::EventFlags::Read, fiber) do |s, flags, data|
      (data as Fiber).resume
    end
  end
end
