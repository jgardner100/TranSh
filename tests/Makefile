
# change these to proper directories where each file should be
SRCDIR   = .
OBJDIR   = obj

#
SOURCES  := $(wildcard $(SRCDIR)/*.my)
OBJECTS  := $(SOURCES:$(SRCDIR)/%.my=$(OBJDIR)/%.sh)

all:	$(OBJECTS)


$(OBJECTS): $(OBJDIR)/%.sh : $(SRCDIR)/%.my
	mysh -o $@ $^
	@chmod 0755 $@
	@echo "Compiled "$<" successfully!"

all:	$(OBJECTS)
	@echo done

clean:
	rm -f $(OBJDIR)/*.sh
